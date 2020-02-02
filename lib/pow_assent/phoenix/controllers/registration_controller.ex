defmodule PowAssent.Phoenix.RegistrationController do
  @moduledoc false
  use Pow.Extension.Phoenix.Controller.Base

  alias Plug.Conn
  alias PowAssent.Plug
  alias Pow.Extension.Config, as: ExtensionConfig
  alias Pow.Plug, as: PowPlug
  alias PowEmailConfirmation.Phoenix.ControllerCallbacks, as: EmailConfirmationCallbacks

  plug :load_params_from_session
  plug :assign_create_path

  @spec process_add_user_id(Conn.t(), map()) :: {:ok, map(), Conn.t()}
  def process_add_user_id(conn, _params) do
    {:ok, Plug.change_user(conn), conn}
  end

  @spec respond_add_user_id({:ok, map(), Conn.t()}) :: Conn.t()
  def respond_add_user_id({:ok, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("add_user_id.html")
  end

  @spec process_create(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, map(), Conn.t()}
  def process_create(%{private: %{pow_assent_callback_params: %{user_identity: user_identity_params, user: user_params}}} = conn, %{"user" => user_id_params}) do
    Plug.create_user(conn, user_identity_params, user_params, user_id_params)
  end

  @spec respond_create({:ok, map(), Conn.t()} | {:error, map(), Conn.t()}) :: Conn.t()
  def respond_create({:ok, user, conn}) do
    conn =  Conn.delete_session(conn, :pow_assent_callback_params)

    maybe_trigger_email_confirmed_controller_callback({:ok, user, conn}, fn {:ok, _user, conn} ->
      conn
      |> put_flash(:info, extension_messages(conn).user_has_been_created(conn))
      |> redirect(to: routes(conn).after_registration_path(conn))
    end)
  end
  def respond_create({:error, {:bound_to_different_user, _changeset}, conn}) do
    conn
    |> put_flash(:error, extension_messages(conn).account_already_bound_to_other_user(conn))
    |> redirect(to: routes(conn).registration_path(conn, :new))
  end
  def respond_create({:error, {:invalid_user_id_field, changeset}, conn}) do
    maybe_trigger_email_confirmed_controller_callback({:error, changeset, conn}, &respond_create/1)
  end
  def respond_create({:error, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("add_user_id.html")
  end

  defp maybe_trigger_email_confirmed_controller_callback({:ok, _user, conn} = resp, callback) do
    config = PowPlug.fetch_config(conn)

    maybe_trigger_email_confirmed_controller_callback(resp, callback, config)
  end
  defp maybe_trigger_email_confirmed_controller_callback({:error, _changeset, conn} = resp, callback) do
    config = PowPlug.fetch_config(conn)

    maybe_trigger_email_confirmed_controller_callback(resp, callback, config)
  end
  defp maybe_trigger_email_confirmed_controller_callback(resp, callback, config) do
    config
    |> ExtensionConfig.extensions()
    |> Enum.member?(PowEmailConfirmation)
    |> case do
      true  -> EmailConfirmationCallbacks.before_respond(Pow.Phoenix.RegistrationController, :create, resp, config)
      false -> resp
    end
    |> case do
      {:halt, conn} -> conn
      resp          -> callback.(resp)
    end
  end

  defp load_params_from_session(%{params: %{"provider" => provider}, private: %{plug_session: plug_session}} = conn, _opts) do
    case plug_session do
      %{"pow_assent_callback_params" => %{^provider => params}} ->
        Conn.put_private(conn, :pow_assent_callback_params, params)

      _ ->
        conn
        |> put_flash(:error, extension_messages(conn).invalid_request(conn))
        |> redirect(to: routes(conn).after_sign_out_path(conn))
        |> halt()
    end
  end

  defp assign_create_path(conn, _opts) do
    path = routes(conn).path_for(conn, __MODULE__, :create, [conn.params["provider"]])
    Conn.assign(conn, :action, path)
  end
end
