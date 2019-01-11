defmodule PowAssent.Strategy.FacebookTest do
  use PowAssent.Test.Phoenix.ConnCase

  import OAuth2.TestHelpers
  alias PowAssent.Strategy.Facebook

  @access_token "access_token"

  setup %{conn: conn} do
    bypass = Bypass.open()
    config = [site: bypass_server(bypass), client_secret: ""]

    {:ok, conn: conn, config: config, bypass: bypass}
  end

  test "authorize_url/2", %{conn: conn, config: config} do
    assert {:ok, %{conn: _conn, url: url}} = Facebook.authorize_url(config, conn)
    assert url =~ "https://www.facebook.com/v2.12/dialog/oauth?client_id="
  end

  describe "callback/2" do
    setup %{conn: conn, config: config, bypass: bypass} do
      params = %{"code" => "test", "redirect_uri" => "test", "state" => "test"}
      conn = Plug.Conn.put_private(conn, :pow_assent_state, "test")

      {:ok, conn: conn, config: config, params: params, bypass: bypass}
    end

    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/access_token", fn conn ->
        assert conn.query_string =~ "scope=email"
        assert conn.query_string =~ "redirect_uri=test"

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{"access_token" => @access_token}))
      end)

      Bypass.expect_once(bypass, "GET", "/me", fn conn ->
        assert_access_token_in_header(conn, @access_token)

        conn = Plug.Conn.fetch_query_params(conn)

        assert conn.params["fields"] == "name,email"

        assert conn.params["appsecret_proof"] ==
                 Base.encode16(:crypto.hmac(:sha256, "", @access_token), case: :lower)

        user = %{name: "Dan Schultzer", email: "foo@example.com", id: "1"}

        conn
        |> put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(user))
      end)

      expected = %{
        "email" => "foo@example.com",
        "image" => "#{bypass_server(bypass)}/1/picture",
        "name" => "Dan Schultzer",
        "uid" => "1",
        "urls" => %{}
      }

      {:ok, %{user: user}} = Facebook.callback(config, conn, params)
      assert expected == user
    end

    test "handles error", %{config: config, conn: conn, params: params} do
      config = Keyword.put(config, :site, "http://localhost:8888")

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = Facebook.callback(config, conn, params)
      assert error == :econnrefused
    end
  end
end
