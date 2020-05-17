defmodule PowAssent.Phoenix.ReauthorizationPlugHandlerTest do
  use PowAssent.Test.Phoenix.ConnCase

  alias Pow.{Config.ConfigError, Plug}
  alias PowAssent.{Phoenix.ReauthorizationPlugHandler, Plug.Reauthorization}

  @endpoint PowAssent.Test.Reauthorization.Phoenix.Endpoint

  test "when at session path without cookie does not redirect", %{conn: conn} do
    conn = get(conn, Routes.pow_session_path(conn, :new))

    assert html_response(conn, 200)
  end

  test "when not at session path without cookie does not redirect", %{conn: conn} do
    conn =
      conn
      |> with_reauthorization_cookie()
      |> get(Routes.pow_registration_path(conn, :new))

    assert html_response(conn, 200)
  end

  test "when at session path with cookie redirects", %{conn: conn} do
    conn =
      conn
      |> with_reauthorization_cookie()
      |> get(Routes.pow_session_path(conn, :new))

    assert redirected_to(conn) == Routes.pow_assent_authorization_path(conn, :new, "test_provider")
  end

  test "when at session path with cookie redirects with request_path", %{conn: conn} do
    conn =
      conn
      |> with_reauthorization_cookie()
      |> get(Routes.pow_session_path(conn, :new, request_path: "/custom-url"))

    assert redirected_to(conn) == Routes.pow_assent_authorization_path(conn, :new, "test_provider", request_path: "/custom-url")
  end

  defp with_reauthorization_cookie(conn) do
    Map.put(conn, :cookies, %{"pow_assent_reauthorization_provider" => "test_provider"})
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
