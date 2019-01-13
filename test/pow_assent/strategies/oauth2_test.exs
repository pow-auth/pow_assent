defmodule PowAssent.Strategy.OAuth2Test do
  use PowAssent.Test.Phoenix.ConnCase

  import PowAssent.OAuthHelpers
  alias PowAssent.Strategy.OAuth2, as: OAuth2Strategy

  setup :setup_bypass

  setup context do
    config = Keyword.put(context[:config], :user_url, "/api/user")

    {:ok, Map.to_list(%{context | config: config})}
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
      expect_oauth2_access_token_request(bypass)
      expect_oauth2_user_request(bypass, %{name: "Dan Schultzer", email: "foo@example.com", uid: "1"})

      assert {:ok, %{conn: _conn, user: user}} = OAuth2Strategy.callback(config, conn, params)
      assert user == %{"email" => "foo@example.com", "name" => "Dan Schultzer", "uid" => "1"}
    end

    test "access token error with 200 response", %{conn: conn, config: config, params: params, bypass: bypass} do
      expect_oauth2_access_token_request(bypass, params: %{"error" => "error", "error_description" => "Error description"})

      expected = %PowAssent.RequestError{error: "error", message: "Error description"}

      assert {:error, %{conn: _conn, error: error}} = OAuth2Strategy.callback(config, conn, params)

      assert error == expected
    end

    test "access token error with no 2XX response", %{conn: conn, config: config, params: params, bypass: bypass} do
      expect_oauth2_access_token_request(bypass, status_code: 500, params: %{error: "Error"})

      expected = %PowAssent.RequestError{error: nil, message: "Error"}

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = OAuth2Strategy.callback(config, conn, params)
      assert error == expected
    end

    test "configuration error", %{conn: conn, config: config, params: params, bypass: bypass} do
      config = Keyword.put(config, :user_url, nil)

      expect_oauth2_access_token_request(bypass)

      expected = %PowAssent.ConfigurationError{message: "No user URL set"}

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = OAuth2Strategy.callback(config, conn, params)
      assert error == expected
    end

    test "user url connection error", %{conn: conn, config: config, params: params, bypass: bypass} do
      config = Keyword.put(config, :user_url, "http://localhost:8888/api/user")

      expect_oauth2_access_token_request(bypass)

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = OAuth2Strategy.callback(config, conn, params)
      assert error == :econnrefused
    end

    test "user url unauthorized access token", %{conn: conn, config: config, params: params, bypass: bypass} do
      expect_oauth2_access_token_request(bypass)
      expect_oauth2_user_request(bypass, %{"error" => "Unauthorized"}, status_code: 401)

      expected = %PowAssent.RequestError{message: "Unauthorized token"}

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = OAuth2Strategy.callback(config, conn, params)
      assert error == expected
    end
  end
end
