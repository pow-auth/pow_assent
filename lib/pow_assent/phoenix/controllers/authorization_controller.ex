defmodule PowAssent.Phoenix.AuthorizationController do
  @moduledoc false
  use Pow.Extension.Phoenix.Controller.Base,
    messages_backend_fallback: PowAssent.Phoenix.Messages

  alias Plug.Conn
  alias PowAssent.Plug
  alias PowAssent.Phoenix.{AuthorizationController, RegistrationController}
  alias PowEmailConfirmation.Phoenix.ControllerCallbacks

  plug :require_authenticated when action in [:delete]
  plug :assign_callback_url when action in [:new, :callback]

  @spec process_new(Conn.t(), map()) :: {:ok, binary(), Conn.t()} | {:error, any(), Conn.t()}
  def process_new(conn, %{"provider" => provider}) do
    Plug.authorize_url(conn, provider, conn.assigns.callback_url)
  end

  @spec respond_new({:ok, binary(), Conn.t()} | {:error, any(), Conn.t()}) :: Conn.t()
  def respond_new({:ok, url, conn}) do
    conn
    |> maybe_store_state()
    |> redirect(external: url)
  end
  def respond_new({:error, error, _conn}), do: handle_strategy_error(error)

  defp maybe_store_state(%{private: %{pow_assent_state: state}} = conn), do: store_state(conn, state)
  defp maybe_store_state(conn), do: conn

  @spec process_callback(Conn.t(), map()) :: {:ok, Conn.t()} | {:error, Conn.t()} | {:error, {atom(), map()} | map(), Conn.t()}
  def process_callback(conn, %{"provider" => provider} = params) do
    conn
    |> maybe_load_state()
    |> Plug.callback(provider, params, conn.assigns.callback_url)
    |> handle_callback(provider)
  end

  defp maybe_load_state(conn) do
    case fetch_state(conn) do
      {state, conn} -> Conn.put_private(conn, :pow_assent_state, state)
      conn          -> conn
    end
  end

  defp handle_callback({:ok, user, conn}, provider) do
    conn
    |> Pow.Plug.current_user()
    |> authenticate_or_create_identity(provider, user, conn)
  end
  defp handle_callback({:error, error, _conn}, _provider), do: handle_strategy_error(error)

  defp authenticate_or_create_identity(nil, provider, user, conn) do
    conn
    |> Plug.authenticate(provider, user)
    |> maybe_create_user(provider, user)
  end
  defp authenticate_or_create_identity(_user, provider, user, conn) do
    conn
    |> Plug.create_identity(provider, user)
    |> case do
      {:ok, _user_identity, conn} -> {:ok, conn}
      {:error, error, conn}       -> {:error, error, conn}
    end
  end

  defp maybe_create_user({:ok, conn}, _provider, _user), do: {:ok, conn}
  defp maybe_create_user({:error, conn}, provider, user) do
    case registration_path?(conn) do
      true  -> create_user(conn, provider, user)
      false -> {:error, conn}
    end
  end

  defp registration_path?(conn) do
    [conn.private.phoenix_router, Helpers]
    |> Module.concat()
    |> function_exported?(:pow_assent_registration_path, 3)
  end

  defp create_user(conn, provider, user) do
    case Plug.create_user(conn, provider, user) do
      {:ok, _user, conn}    -> {:ok, Conn.put_private(conn, :pow_assent_action, :registration)}
      {:error, error, conn} -> {:error, error, Conn.put_private(conn, :pow_assent_params, user)}
    end
  end

  @spec respond_callback({:ok, Conn.t()} | {:error, Conn.t()} | {:error, {atom(), map()} | map(), Conn.t()}) :: Conn.t()
  def respond_callback({:ok, %{private: %{pow_assent_action: :registration}} = conn}) do
    case email_confirmed_controller_callback(:registration, conn) do
      {:halt, conn} ->
        conn
      {:ok, _user, conn} ->
        conn
        |> put_flash(:info, messages(conn).user_has_been_created(conn))
        |> redirect(to: routes(conn).after_registration_path(conn))
    end
  end
  def respond_callback({:ok, conn}) do
    case email_confirmed_controller_callback(:session, conn) do
      {:halt, conn} ->
        conn
      {:ok, conn} ->
        conn
        |> put_flash(:info, messages(conn).signed_in(conn))
        |> redirect(to: routes(conn).after_sign_in_path(conn))
    end
  end
  def respond_callback({:error, {:bound_to_different_user, _changeset}, conn}) do
    conn
    |> put_flash(:error, messages(conn).account_already_bound_to_other_user(conn))
    |> redirect(to: routes(conn).session_path(conn, :new))
  end
  def respond_callback({:error, {:invalid_user_id_field, _changeset}, %{params: %{"provider" => provider}, private: %{pow_assent_params: params}} = conn}) do
    conn
    |> Conn.put_session(:pow_assent_params, %{provider => params})
    |> redirect(to: routes(conn).path_for(conn, RegistrationController, :add_user_id, [conn.params["provider"]]))
  end
  def respond_callback({:error, _changeset, conn}),
    do: respond_callback({:error, conn})
  def respond_callback({:error, conn}) do
    conn
    |> put_flash(:error, messages(conn).could_not_sign_in(conn))
    |> redirect(to: routes(conn).session_path(conn, :new))
  end

  defp email_confirmed_controller_callback(:registration, conn) do
    ControllerCallbacks.before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, Pow.Plug.current_user(conn), conn}, [])
  end
  defp email_confirmed_controller_callback(:session, conn) do
    ControllerCallbacks.before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, [])
  end

  @spec process_delete(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, any(), Conn.t()}
  def process_delete(conn, %{"provider" => provider}) do
    Plug.delete_identity(conn, provider)
  end

  @spec respond_delete({:ok, map(), Conn.t()}) :: Conn.t()
  def respond_delete({:ok, _deleted, conn}) do
    conn
    |> put_flash(:info, messages(conn).authentication_has_been_removed(conn))
    |> redirect(to: after_delete_path(conn))
  end
  def respond_delete({:error, {:no_password, _changeset}, conn}) do
    conn
    |> put_flash(:error, messages(conn).identity_cannot_be_removed_missing_user_password(conn))
    |> redirect(to: after_delete_path(conn))
  end

  defp after_delete_path(conn), do: routes(conn).registration_path(conn, :edit)

  defp assign_callback_url(conn, _opts) do
    url = routes(conn).url_for(conn, AuthorizationController, :callback, [conn.params["provider"]])

    assign(conn, :callback_url, url)
  end

  defp store_state(conn, state) do
    Conn.put_session(conn, :pow_assent_state, state)
  end

  defp fetch_state(%{private: %{plug_session: %{"pow_assent_state" => state}}} = conn) do
    {state, Conn.put_session(conn, :pow_assent_state, nil)}
  end
  defp fetch_state(conn), do: conn

  defp handle_strategy_error(error), do: raise error
end
