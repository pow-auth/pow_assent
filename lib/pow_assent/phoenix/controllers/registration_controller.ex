defmodule PowAssent.Phoenix.RegistrationController do
  @moduledoc false
  use Pow.Extension.Phoenix.Controller.Base,
    messages_backend_fallback: PowAssent.Phoenix.Messages

  alias Plug.Conn
  alias PowAssent.Plug
  alias PowEmailConfirmation.Phoenix.ControllerCallbacks

  plug :load_params_from_session
  plug :assign_create_path

  @spec process_add_user_id(Conn.t(), map()) :: {:ok, map(), Conn.t()}
  def process_add_user_id(conn, _params) do
    {:ok, Pow.Plug.change_user(conn), conn}
  end

  @spec respond_add_user_id({:ok, map(), Conn.t()}) :: Conn.t()
  def respond_add_user_id({:ok, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("add_user_id.html")
  end

  @spec process_create(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def process_create(%{private: %{pow_assent_params: user_params}} = conn, %{"provider" => provider, "user" => user_id_params}) do
    Plug.create_user(conn, provider, user_params, user_id_params)
  end

  @spec respond_create({:ok, map(), Conn.t()} | {:error, map(), Conn.t()}) :: Conn.t()
  def respond_create({:ok, user, conn}) do
    conn
    |> Conn.delete_session(:pow_assent_params)
    |> email_confirmed_controller_callback(user)
    |> case do
      {:halt, conn} ->
        conn
      {:ok, _user, conn} ->
        conn
        |> put_flash(:info, messages(conn).user_has_been_created(conn))
        |> redirect(to: routes(conn).after_registration_path(conn))
    end
  end
  def respond_create({:error, {:bound_to_different_user, _changeset}, conn}) do
    conn
    |> put_flash(:error, messages(conn).account_already_bound_to_other_user(conn))
    |> redirect(to: routes(conn).registration_path(conn, :new))
  end
  def respond_create({:error, {:invalid_user_id_field, changeset}, conn}),
    do: respond_create({:error, changeset, conn})
  def respond_create({:error, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("add_user_id.html")
  end

  defp email_confirmed_controller_callback(conn, user) do
    ControllerCallbacks.before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, user, conn}, [])
  end

  defp load_params_from_session(%{params: %{"provider" => provider}, private: %{plug_session: plug_session}} = conn, _opts) do
    case plug_session do
      %{"pow_assent_params" => %{^provider => params}} ->
        Conn.put_private(conn, :pow_assent_params, params)

      _ ->
        conn
        |> put_flash(:error, messages(conn).invalid_request(conn))
        |> redirect(to: routes(conn).after_sign_out_path(conn))
        |> halt()
    end
  end

  defp assign_create_path(conn, _opts) do
    path = routes(conn).path_for(conn, __MODULE__, :create, [conn.params["provider"]])
    Conn.assign(conn, :action, path)
  end
end
