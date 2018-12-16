defmodule PowAssent.Strategy.OAuth2Test do
  use PowAssent.Test.Phoenix.ConnCase

  import OAuth2.TestHelpers
  alias PowAssent.Strategy.OAuth2, as: OAuth2Strategy

  @access_token "access_token"

  setup %{conn: conn} do
    bypass = Bypass.open()
    config = [site: bypass_server(bypass), user_url: "/api/user"]

    {:ok, conn: conn, config: config, bypass: bypass}
  end

  test "authorize_url/2", %{conn: conn, config: config} do
    assert {:ok, %{conn: conn, url: url, state: state}} = OAuth2Strategy.authorize_url(config, conn)

    assert conn.private[:pow_assent_state] == state
    assert url == "#{config[:site]}/oauth/authorize?client_id=&redirect_uri=&response_type=code&state=#{state}"
  end

  describe "callback/2" do
    setup %{conn: conn, config: config, bypass: bypass} do
      conn = Plug.Conn.put_private(conn, :pow_assent_state, "test")
      params = %{"code" => "test", "redirect_uri" => "test", "state" => "test"}

      {:ok, conn: conn, config: config, params: params, bypass: bypass}
    end

    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        send_resp(conn, 200, Jason.encode!(%{access_token: @access_token}))
      end)

      Bypass.expect_once(bypass, "GET", "/api/user", fn conn ->
        assert_access_token_in_header(conn, @access_token)

        user = %{name: "Dan Schultzer", email: "foo@example.com", uid: "1"}
        Plug.Conn.resp(conn, 200, Jason.encode!(user))
      end)

      assert {:ok, %{conn: _conn, user: user}} = OAuth2Strategy.callback(config, conn, params)
      assert user == %{"email" => "foo@example.com", "name" => "Dan Schultzer", "uid" => "1"}
    end

    test "access token error with 200 response", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        send_resp(conn, 200, Jason.encode!(%{"error" => "error", "error_description" => "Error description"}))
      end)

      expected = %PowAssent.RequestError{error: "error", message: "Error description"}

      assert {:error, %{conn: _conn, error: error}} = OAuth2Strategy.callback(config, conn, params)

      assert error == expected
    end

    test "access token error with no 2XX response", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        send_resp(conn, 500, Jason.encode!(%{error: "Error"}))
      end)

      expected = %PowAssent.RequestError{error: nil, message: "Error"}

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = OAuth2Strategy.callback(config, conn, params)
      assert error == expected
    end

    test "configuration error", %{conn: conn, config: config, params: params, bypass: bypass} do
      config = Keyword.put(config, :user_url, nil)

      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        send_resp(conn, 200, Jason.encode!(%{access_token: @access_token}))
      end)

      expected = %PowAssent.ConfigurationError{message: "No user URL set"}

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = OAuth2Strategy.callback(config, conn, params)
      assert error == expected
    end

    test "user url connection error", %{conn: conn, config: config, params: params, bypass: bypass} do
      config = Keyword.put(config, :user_url, "http://localhost:8888/api/user")

      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{access_token: @access_token}))
      end)

      expected = %OAuth2.Error{reason: :econnrefused}

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = OAuth2Strategy.callback(config, conn, params)
      assert error == expected
    end

    test "user url unauthorized access token", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{access_token: @access_token}))
      end)

      Bypass.expect_once(bypass, "GET", "/api/user", fn conn ->
        assert_access_token_in_header(conn, @access_token)
        conn
        |> put_resp_content_type("application/json")
        |> Plug.Conn.resp(401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      expected = %PowAssent.RequestError{message: "Unauthorized token"}

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = OAuth2Strategy.callback(config, conn, params)
      assert error == expected
    end
  end
end
