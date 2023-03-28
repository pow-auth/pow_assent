defmodule PowAssent.Phoenix.ReauthorizationPlugHandlerTest do
  use PowAssent.Test.Phoenix.ConnCase

  alias Pow.{Config.ConfigError, Plug}
  alias PowAssent.{Phoenix.ReauthorizationPlugHandler, Plug.Reauthorization}

  @endpoint PowAssent.Test.Reauthorization.Phoenix.Endpoint
  @cookie_key "pow_assent_reauthorization_provider"

  test "when at session new path without cookie does not redirect", %{conn: conn} do
    conn = get(conn, ~p"/session/new")

    assert html_response(conn, 200)
    refute conn.resp_cookies[@cookie_key]
  end

  test "when not at session new path without cookie does not redirect", %{conn: conn} do
    conn =
      conn
      |> with_reauthorization_cookie()
      |> get(~p"/registration/new")

    assert html_response(conn, 200)
    refute conn.resp_cookies[@cookie_key]
  end

  test "when at session new path with cookie redirects", %{conn: conn} do
    conn =
      conn
      |> with_reauthorization_cookie()
      |> get(~p"/session/new")

    assert redirected_to(conn) == ~p"/auth/test_provider/new"
    assert conn.resp_cookies[@cookie_key]
  end

  test "when at session new path with cookie redirects with request_path", %{conn: conn} do
    conn =
      conn
      |> with_reauthorization_cookie()
      |> get(~p"/session/new?#{[request_path: "/custom-url"]}")

    assert redirected_to(conn) == ~p"/auth/test_provider/new?#{[request_path: "/custom-url"]}"
    assert conn.resp_cookies[@cookie_key]
  end

  test "when at session delete path with cookie clears", %{conn: conn} do
    conn =
      conn
      |> with_reauthorization_cookie()
      |> delete(~p"/session")

    assert redirected_to(conn) == ~p"/session/new"
    assert conn.resp_cookies[@cookie_key]
  end

  defp with_reauthorization_cookie(conn) do
    Map.put(conn, :cookies, %{@cookie_key => "test_provider"})
  end

  test "requires conn.private.phoenix_controller", %{conn: conn} do
    assert_raise ConfigError, "Please use PowAssent.Plug.Reauthorization plug in your Phoenix router rather than endpoint when used with the PowAssent.Phoenix.ReauthorizationPlugHandler handler.", fn ->
      opts = Reauthorization.init(handler: ReauthorizationPlugHandler)

      conn
      |> Plug.put_config([])
      |> Reauthorization.call(opts)
    end
  end
end
