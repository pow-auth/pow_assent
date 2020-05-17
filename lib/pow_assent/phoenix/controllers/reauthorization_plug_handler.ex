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

    request?(conn, "GET", path)
  end

  defp request?(%{method: method, request_path: path}, method, expected_path),
    do: compare_paths(path, expected_path)
  defp request?(_conn, _method, _expected_path), do: false

  defp compare_paths(path_1, path_2) when is_binary(path_1), do: compare_paths(URI.parse(path_1), path_2)
  defp compare_paths(path_1, path_2) when is_binary(path_2), do: compare_paths(path_1, URI.parse(path_2))
  defp compare_paths(%{path: path}, %{path: path}), do: true
  defp compare_paths(_, _), do: false

  @spec reauthorize(Conn.t(), binary(), Config.t()) :: Conn.t()
  def reauthorize(conn, provider, config) do
    check_conn!(conn, config)

    params = Map.take(conn.params, ["request_path"])
    path   = AuthorizationController.routes(conn).path_for(conn, AuthorizationController, :new, [provider], params)

    Controller.redirect(conn, to: path)
  end

  defp check_conn!(%{private: %{phoenix_router: _router}}, _config), do: :ok
  defp check_conn!(_conn, config), do: raise_missing_phoenix_router(config)

  @spec clear_reauthorization?(Conn.t(), Config.t()) :: boolean()
  def clear_reauthorization?(conn, config) do
    check_conn!(conn, config)

    path = SessionController.routes(conn).path_for(conn, SessionController, :delete)

    request?(conn, "DELETE", path)
  end

  @spec raise_missing_phoenix_router(Config.t()) :: no_return()
  defp raise_missing_phoenix_router(config) do
    Config.raise_error("Please use #{inspect config[:reauthorization_plug]} plug in your Phoenix router rather than endpoint when used with the #{inspect __MODULE__} handler.")
  end
end
