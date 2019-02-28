defmodule PowAssent.Strategy.FacebookTest do
  use PowAssent.Test.Phoenix.ConnCase

  import PowAssent.OAuthHelpers
  alias PowAssent.Strategy.Facebook

  @user_response %{name: "Dan Schultzer", email: "foo@example.com", id: "1"}

  setup :setup_bypass

  setup context do
    config = Keyword.put(context[:config], :client_secret, "")

    {:ok, Map.to_list(%{context | config: config})}
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
      expect_oauth2_access_token_request(bypass, [uri: "/oauth/access_token"], fn conn ->
        assert conn.query_string =~ "scope=email"
        assert conn.query_string =~ "redirect_uri=test"
      end)

      expect_oauth2_user_request(bypass, @user_response, [uri: "/me"], fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        assert conn.params["access_token"] == "access_token"
        assert conn.params["fields"] == "name,email"
        assert conn.params["appsecret_proof"] == Base.encode16(:crypto.hmac(:sha256, "", "access_token"), case: :lower)
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

      assert {:error, %{conn: %Plug.Conn{}, error: %PowAssent.RequestError{error: :unreachable}}} = Facebook.callback(config, conn, params)
    end
  end
end
