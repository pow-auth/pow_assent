defmodule PowAssent.Phoenix.AuthorizationController do
  @moduledoc false
  use Pow.Extension.Phoenix.Controller.Base

  alias Plug.Conn
  alias PowAssent.Plug
  alias PowAssent.Phoenix.{AuthorizationController, RegistrationController}
  alias Pow.Extension.Config, as: ExtensionConfig
  alias Pow.Plug, as: PowPlug
  alias PowEmailConfirmation.Phoenix.ControllerCallbacks, as: EmailConfirmationCallbacks

  plug :require_authenticated when action in [:delete]
  plug :assign_callback_url when action in [:new, :callback]
  plug :assign_request_path when action in [:callback]
  plug :load_user_by_invitation_token when action in [:callback]

  @spec process_new(Conn.t(), map()) :: {:ok, binary(), Conn.t()} | {:error, any(), Conn.t()}
  def process_new(conn, %{"provider" => provider}) do
    Plug.authorize_url(conn, provider, conn.assigns.callback_url)
  end

  @spec respond_new({:ok, binary(), Conn.t()} | {:error, any(), Conn.t()}) :: Conn.t()
  def respond_new({:ok, url, conn}) do
    conn
    |> maybe_store_session_params()
    |> maybe_store_request_path()
    |> maybe_store_invitation_token()
    |> redirect(external: url)
  end
  def respond_new({:error, error, _conn}), do: handle_strategy_error(error)

  defp maybe_store_session_params(%{private: %{pow_assent_session_params: params}} = conn), do: store_session_params(conn, params)
  defp maybe_store_session_params(conn), do: conn

  defp maybe_store_request_path(%{params: %{"request_path" => request_path}} = conn), do: store_request_path(conn, request_path)
  defp maybe_store_request_path(conn), do: conn

  defp maybe_store_invitation_token(%{params: %{"invitation_token" => token}} = conn), do: store_invitation_token(conn, token)
  defp maybe_store_invitation_token(conn), do: conn

  @spec process_callback(Conn.t(), map()) :: {:ok, Conn.t()} | {:error, Conn.t()} | {:error, {atom(), map()} | map(), Conn.t()}
  def process_callback(conn, %{"provider" => provider} = params) do
    conn
    |> load_session_params()
    |> maybe_assign_invited_user()
    |> Plug.callback(provider, params, conn.assigns.callback_url)
    |> upsert_identity_or_authenticate_or_create_user()
  end

  defp load_session_params(conn) do
    case fetch_session_params(conn) do
      {params, conn} -> Conn.put_private(conn, :pow_assent_session_params, params)
      conn           -> conn
    end
  end

  defp maybe_assign_invited_user(%{assigns: %{invited_user: invited_user}} = conn) do
    config = Pow.Plug.fetch_config(conn)

    Pow.Plug.assign_current_user(conn, invited_user, config)
  end
  defp maybe_assign_invited_user(conn), do: conn

  defp upsert_identity_or_authenticate_or_create_user({:ok, user_identity_params, user_params, conn}) do
    case Pow.Plug.current_user(conn) do
      nil   -> authenticate_or_create_user(conn, user_identity_params, user_params)
      _user -> upsert_user_identity(conn, user_identity_params)
    end
  end
  defp upsert_identity_or_authenticate_or_create_user({:error, error, _conn}), do: handle_strategy_error(error)

  defp upsert_user_identity(conn, user_identity_params) do
    conn
    |> Plug.upsert_identity(user_identity_params)
    |> case do
      {:ok, _user, conn}    -> {:ok, conn}
      {:error, error, conn} -> {:error, error, conn}
    end
  end

  defp authenticate_or_create_user(conn, user_identity_params, user_params) do
    case Plug.authenticate(conn, user_identity_params) do
      {:ok, conn}    -> upsert_user_identity(conn, user_identity_params)
      {:error, conn} -> create_user(conn, user_identity_params, user_params)
    end
  end

  defp create_user(conn, user_identity_params, user_params) do
    conn = Conn.put_private(conn, :pow_assent_action, :registration)

    case registration_path?(conn) do
      true  -> do_create_user(conn, user_identity_params, user_params)
      false -> {:error, conn}
    end
  end

  defp registration_path?(conn) do
    [conn.private.phoenix_router, Helpers]
    |> Module.concat()
    |> function_exported?(:pow_assent_registration_path, 3)
  end

  defp do_create_user(conn, user_identity_params, user_params) do
    case Plug.create_user(conn, user_identity_params, user_params) do
      {:ok, _user, conn} ->
        {:ok, conn}

      {:error, changeset, conn} ->
        conn = Conn.put_private(conn, :pow_assent_params, %{user_identity: user_identity_params, user: user_params})

        {:error, changeset, conn}
    end
  end

  @spec respond_callback({:ok, Conn.t()} | {:error, Conn.t()} | {:error, {atom(), map()} | map(), Conn.t()}) :: Conn.t()
  def respond_callback({:ok, %{private: %{pow_assent_action: :registration}}} = resp) do
    maybe_trigger_email_confirmed_controller_callback(resp, fn {:ok, conn} ->
      conn
      |> put_flash(:info, extension_messages(conn).user_has_been_created(conn))
      |> redirect(to: routes(conn).after_registration_path(conn))
    end)
  end
  def respond_callback({:ok, _conn} = resp) do
    maybe_trigger_email_confirmed_controller_callback(resp, fn {:ok, conn} ->
      conn
      |> put_flash(:info, extension_messages(conn).signed_in(conn))
      |> redirect(to: routes(conn).after_sign_in_path(conn))
    end)
  end
  def respond_callback({:error, {:bound_to_different_user, _changeset}, conn}) do
    conn
    |> put_flash(:error, extension_messages(conn).account_already_bound_to_other_user(conn))
    |> redirect(to: routes(conn).session_path(conn, :new))
  end
  def respond_callback({:error, {:invalid_user_id_field, changeset}, %{params: %{"provider" => provider}, private: %{pow_assent_params: params}} = conn}) do
    maybe_trigger_email_confirmed_controller_callback({:error, changeset, conn}, fn {:error, _changeset, conn} ->
      conn
      |> Conn.put_session(:pow_assent_params, %{provider => params})
      |> redirect(to: routes(conn).path_for(conn, RegistrationController, :add_user_id, [conn.params["provider"]]))
    end)
  end
  def respond_callback({:error, _changeset, conn}),
    do: respond_callback({:error, conn})
  def respond_callback({:error, conn}) do
    conn
    |> put_flash(:error, extension_messages(conn).could_not_sign_in(conn))
    |> redirect(to: routes(conn).session_path(conn, :new))
  end

  defp maybe_trigger_email_confirmed_controller_callback({:ok, conn} = resp, callback) do
    config = PowPlug.fetch_config(conn)
    type   = conn.private[:pow_assent_action]

    maybe_trigger_email_confirmed_controller_callback(resp, type, callback, config)
  end
  defp maybe_trigger_email_confirmed_controller_callback({:error, _changeset, %{private: %{pow_assent_params: params}} = conn} = resp, callback) do
    config   = PowPlug.fetch_config(conn)
    type     = conn.private[:pow_assent_action]

    case email_verified?(params[:user]) do
      true  -> callback.(resp)
      false -> maybe_trigger_email_confirmed_controller_callback(resp, type, callback, config)
    end
  end
  defp maybe_trigger_email_confirmed_controller_callback(resp, type, callback, config) do
    config
    |> ExtensionConfig.extensions()
    |> Enum.member?(PowEmailConfirmation)
    |> case do
      true  -> trigger_email_confirmed_controller_callback(resp, type, config)
      false -> resp
    end
    |> case do
      {:halt, conn} -> conn
      resp          -> callback.(resp)
    end
  end

  defp email_verified?(%{"email_verified" => true}), do: true
  defp email_verified?(%{email_verified: true}), do: true
  defp email_verified?(_params), do: false

  defp trigger_email_confirmed_controller_callback(resp, :registration, config) do
    resp =
      case resp do
        {:ok, conn} -> {:ok, PowPlug.current_user(conn), conn}
        resp        -> resp
      end

    Pow.Phoenix.RegistrationController
    |> EmailConfirmationCallbacks.before_respond(:create, resp, config)
    |> case do
      {:ok, _user, conn} -> {:ok, conn}
      resp               -> resp
    end
  end
  defp trigger_email_confirmed_controller_callback(resp, _type, config) do
    EmailConfirmationCallbacks.before_respond(Pow.Phoenix.SessionController, :create, resp, config)
  end

  @spec process_delete(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, any(), Conn.t()}
  def process_delete(conn, %{"provider" => provider}) do
    Plug.delete_identity(conn, provider)
  end

  @spec respond_delete({:ok, map(), Conn.t()}) :: Conn.t()
  def respond_delete({:ok, _deleted, conn}) do
    conn
    |> put_flash(:info, extension_messages(conn).authentication_has_been_removed(conn))
    |> redirect(to: after_delete_path(conn))
  end
  def respond_delete({:error, {:no_password, _changeset}, conn}) do
    conn
    |> put_flash(:error, extension_messages(conn).identity_cannot_be_removed_missing_user_password(conn))
    |> redirect(to: after_delete_path(conn))
  end

  defp after_delete_path(conn), do: routes(conn).registration_path(conn, :edit)

  defp assign_callback_url(conn, _opts) do
    url = routes(conn).url_for(conn, AuthorizationController, :callback, [conn.params["provider"]])

    assign(conn, :callback_url, url)
  end

  defp store_session_params(conn, params), do: Conn.put_session(conn, :pow_assent_session_params, params)

  defp fetch_session_params(%{private: %{plug_session: %{"pow_assent_session_params" => params}}} = conn) do
    {params, Conn.put_session(conn, :pow_assent_session_params, nil)}
  end
  defp fetch_session_params(conn), do: conn

  defp store_request_path(conn, request_path), do: Conn.put_session(conn, :pow_assent_request_path, request_path)

  defp store_invitation_token(conn, token), do: Conn.put_session(conn, :pow_assent_invitation_token, token)

  defp assign_request_path(%{private: %{plug_session: %{"pow_assent_request_path" => request_path}}} = conn, _opts) do
    conn
    |> Conn.delete_session(:pow_assent_request_path)
    |> Conn.assign(:request_path, request_path)
  end
  defp assign_request_path(conn, _opts), do: conn

  defp load_user_by_invitation_token(%{private: %{plug_session: %{"pow_assent_invitation_token" => token}}} = conn, _opts) do
    conn = Conn.delete_session(conn, :pow_assent_invitation_token)

    conn
    |> PowInvitation.Plug.invited_user_from_token(token)
    |> case do
      nil  -> conn
      user -> PowInvitation.Plug.assign_invited_user(conn, user)
    end
  end
  defp load_user_by_invitation_token(conn, _opts), do: conn

  defp handle_strategy_error(error), do: raise error
end
