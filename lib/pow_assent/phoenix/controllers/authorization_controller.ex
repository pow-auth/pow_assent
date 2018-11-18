defmodule PowAssent.Phoenix.AuthorizationController do
  @moduledoc false
  use Pow.Extension.Phoenix.Controller.Base,
    messages_backend_fallback: PowAssent.Phoenix.Messages

  alias Plug.Conn
  alias PowAssent.Plug
  alias PowAssent.Phoenix.{AuthorizationController, RegistrationController}
  alias PowEmailConfirmation.Phoenix.{ConfirmationController, ControllerCallbacks}

  plug :require_authenticated when action in [:delete]
  plug :load_state_from_session when action in [:callback]
  plug :assign_callback_url when action in [:new, :callback]

  @spec process_new(Conn.t(), map()) :: {:ok, binary(), Conn.t()} | {:error, any(), Conn.t()}
  def process_new(conn, %{"provider" => provider}) do
    Plug.authenticate(conn, provider, conn.assigns.callback_url)
  end

  @spec respond_new({:ok, binary(), Conn.t()}) :: Conn.t()
  def respond_new({:ok, url, conn}) do
    conn
    |> maybe_set_state()
    |> redirect(external: url)
  end
  @spec respond_new({:error, any(), Conn.t()}) :: Conn.t()
  def respond_new({:error, error, _conn}), do: handle_strategy_error(error)

  defp maybe_set_state(%{private: %{pow_assent_state: state}} = conn) do
    Conn.put_session(conn, "pow_assent_state", state)
  end
  defp maybe_set_state(conn), do: conn

  @spec process_callback(Conn.t(), map()) :: {:ok, map(), Conn.t()}
  def process_callback(conn, %{"provider" => provider} = params) do
    params = Map.put(params, "redirect_uri", conn.assigns.callback_url)
    Plug.callback(conn, provider, params)
  end

  @spec respond_callback({:ok, {atom(), map()} | map(), Conn.t()}) :: Conn.t()
  def respond_callback({:ok, {:new, _user}, conn}) do
    conn
    |> put_flash(:info, messages(conn).user_has_been_created(conn))
    |> redirect(to: routes(conn).after_registration_path(conn))
  end
  def respond_callback({:ok, %{email_confirmation_token: token, email_confirmed_at: nil} = user, conn}) when not is_nil(token) do
    {:ok, conn} = Pow.Plug.clear_authenticated_user(conn)

    ControllerCallbacks.send_confirmation_email(user, conn)

    conn
    |> put_flash(:error, ConfirmationController.messages(conn).email_confirmation_required(conn))
    |> redirect(to: routes(conn).session_path(conn, :new))
  end
  def respond_callback({:ok, _user, conn}) do
    conn
    |> put_flash(:info, messages(conn).signed_in(conn))
    |> redirect(to: routes(conn).after_sign_in_path(conn))
  end

  @spec respond_callback({:error, {atom(), map()} | map(), Conn.t()}) :: Conn.t()
  def respond_callback({:error, {:bound_to_different_user, _changeset}, conn}) do
    conn
    |> put_flash(:error, messages(conn).account_already_bound_to_other_user(conn))
    |> redirect(to: routes(conn).registration_path(conn, :new))
  end
  def respond_callback({:error, {:missing_user_id_field, _changeset}, conn}) do
    conn
    |> put_session("pow_assent_params", conn.private[:pow_assent_params])
    |> redirect(to: routes(conn).path_for(conn, RegistrationController, :add_user_id, [conn.params["provider"]]))
  end
  def respond_callback({:error, {:strategy, error}, _conn}), do: handle_strategy_error(error)
  def respond_callback({:error, _error, conn}) do
    conn
    |> put_flash(:error, messages(conn).could_not_sign_in(conn))
    |> redirect(to: routes(conn).session_path(conn, :new))
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

  defp load_state_from_session(%{private: %{plug_session: plug_session}} = conn, _opts) do
    case plug_session do
      %{"pow_assent_state" => state} ->
        conn
        |> Conn.put_private(:pow_assent_state, state)
        |> Conn.put_session("pow_assent_state", nil)

      _ ->
        conn
    end
  end

  defp assign_callback_url(conn, _opts) do
    url = routes(conn).url_for(conn, AuthorizationController, :callback, [conn.params["provider"]])

    assign(conn, :callback_url, url)
  end

  defp handle_strategy_error(error), do: raise error
end
