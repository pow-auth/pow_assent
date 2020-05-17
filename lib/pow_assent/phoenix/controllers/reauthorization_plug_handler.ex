defmodule PowAssent.Phoenix.ReauthorizationPlugHandler do
  @moduledoc """
  Used with `PowAssent.Plug.Reauthorization`.

  ## Example

    plug PowAssent.Plug.Reauthorization,
      handler: PowAssent.Phoenix.ReauthorizationPlugHandler
  """
  alias Phoenix.Controller
  alias Plug.Conn
  alias PowAssent.Phoenix.AuthorizationController
  alias Pow.{Config, Phoenix.SessionController}

  @spec reauthorize?(Conn.t(), Config.t()) :: boolean()
  def reauthorize?(conn, config) do
    check_conn!(conn, config)

    path = SessionController.routes(conn).user_not_authenticated_path(conn)

    compare(URI.parse(conn.request_path), URI.parse(path))
  end

  defp compare(%{path: path}, %{path: path}), do: true
  defp compare(_, _), do: false

  @spec reauthorize(Conn.t(), binary(), Config.t()) :: Conn.t()
  def reauthorize(conn, provider, config) do
    check_conn!(conn, config)

    params = Map.take(conn.params, ["request_path"])
    path   = AuthorizationController.routes(conn).path_for(conn, AuthorizationController, :new, [provider], params)

    Controller.redirect(conn, to: path)
  end

  defp check_conn!(%{private: %{phoenix_router: _router}}, _config), do: :ok
  defp check_conn!(_conn, config), do: raise_missing_phoenix_router(config)

  @spec raise_missing_phoenix_router(Config.t()) :: no_return()
  defp raise_missing_phoenix_router(config) do
    Config.raise_error("Please use #{inspect config[:reauthorization_plug]} plug in your Phoenix router rather than endpoint when used with the #{inspect __MODULE__} handler.")
  end
end
