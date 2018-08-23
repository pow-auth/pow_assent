defmodule PowAssent.Phoenix.RegistrationController do
  @moduledoc false
  use Pow.Extension.Phoenix.Controller.Base,
    messages_backend_fallback: PowAssent.Phoenix.Messages

  alias Plug.Conn
  alias PowAssent.Plug
  alias PowEmailConfirmation.Phoenix.ControllerCallbacks

  plug :load_params_from_session
  plug :assign_create_path

  @spec process_add_user_id(Conn.t(), map()) :: {:ok, Conn.t()}
  def process_add_user_id(conn, _params) do
    {:ok, conn}
  end

  @spec respond_add_user_id({:ok, Conn.t()}) :: Conn.t()
  def respond_add_user_id({:ok, conn}) do
    conn
    |> assign(:changeset, Pow.Plug.change_user(conn, %{}))
    |> render("add_user_id.html")
  end

  @spec process_create(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def process_create(conn, %{"provider" => provider, "user" => user_id_params}) do
    Plug.create_user(conn, provider, conn.private[:pow_assent_params], user_id_params)
  end

  @spec respond_create({:ok, {:new, map()}, Conn.t()}) :: Conn.t()
  def respond_create({:ok, {:new, user}, conn}) do
    conn
    |> maybe_send_confirmation_email(user)
    |> Conn.put_session(:pow_assent_params, nil)
    |> put_flash(:info, messages(conn).user_has_been_created(conn))
    |> redirect(to: routes(conn).after_registration_path(conn))
  end
  @spec respond_create({:error, map(), Conn.t()}) :: Conn.t()
  def respond_create({:error, {:bound_to_different_user, _changeset}, conn}) do
    conn
    |> put_flash(:error, messages(conn).invalid_request(conn))
    |> redirect(to: routes(conn).after_sign_out_path(conn))
  end
  def respond_create({:error, {:missing_user_id_field, changeset}, conn}),
    do: respond_create({:error, changeset, conn})
  def respond_create({:error, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("add_user_id.html")
  end

  defp load_params_from_session(%{private: %{plug_session: plug_session}} = conn, _opts) do
    case plug_session do
      %{"pow_assent_params" => params} ->
        Conn.put_private(conn, :pow_assent_params, params)

      _ ->
        conn
        |> put_flash(:error, messages(conn).invalid_request(conn))
        |> redirect(to: routes(conn).after_sign_out_path(conn))
        |> halt()
    end
  end

  defp assign_create_path(conn, _opts) do
    path = router_helpers(conn).pow_assent_registration_path(conn, :create, conn.params["provider"])
    Conn.assign(conn, :action, path)
  end

  defp maybe_send_confirmation_email(conn, %{email_confirmation_token: token, email_confirmed_at: nil} = user) when not is_nil(token) do
    ControllerCallbacks.send_confirmation_email(user, conn)

    conn
  end
  defp maybe_send_confirmation_email(conn, _user), do: conn
end
