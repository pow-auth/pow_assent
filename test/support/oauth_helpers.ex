defmodule PowAssent.OAuthHelpers do
  @moduledoc false

  alias Plug.Conn

  @spec bypass_server(%Bypass{}) :: String.t()
  def bypass_server(%Bypass{port: port}) do
    "http://localhost:#{port}"
  end

  @spec setup_bypass(map(), Keyword.t()) :: {:ok, Keyword.t()}
  def setup_bypass(context, config \\ []) do
    bypass  = Bypass.open()
    config  = Keyword.merge([site: bypass_server(bypass)], config)
    context = Map.merge(context, %{config: config, bypass: bypass})

    {:ok, Map.to_list(context)}
  end

  @spec setup_bypass_oauth(map(), Keyword.t()) :: {:ok, Keyword.t()}
  def setup_bypass_oauth(context, config \\ []) do
    context = Map.put(context, :params, %{"oauth_token" => "test", "oauth_verifier" => "test"})

    setup_bypass(context, config)
  end

  @spec setup_oauth2_strategy_env(%Bypass{}) :: :ok
  def setup_oauth2_strategy_env(server) do
    Application.put_env(:pow_assent, :pow_assent,
      providers: [
        test_provider: [
          client_id: "client_id",
          client_secret: "abc123",
          site: bypass_server(server),
          strategy: TestProvider
        ]
      ]
    )
  end

  @spec expect_oauth_request_token_request(Bypass.t(), Keyword.t()) :: :ok
  def expect_oauth_request_token_request(bypass, opts \\ []) do
    status_code    = Keyword.get(opts, :status_code, 200)
    content_type   = Keyword.get(opts, :content_type, "application/x-www-form-urlencoded")
    params         = Keyword.get(opts, :params, %{oauth_token: "token", oauth_token_secret: "token_secret"})
    response       =
      case content_type do
        "application/x-www-form-urlencoded" -> URI.encode_query(params)
        "application/json"                  -> Jason.encode!(params)
        _any                                -> params
      end

    Bypass.expect_once(bypass, "POST", "/oauth/request_token", fn conn ->
      conn
      |> Conn.put_resp_content_type(content_type)
      |> Conn.resp(status_code, response)
    end)
  end

  @spec expect_oauth_user_request(Bypass.t(), map(), Keyword.t()) :: :ok
  def expect_oauth_user_request(bypass, user_params, opts \\ []) do
    uri          = Keyword.get(opts, :uri, "/api/user")
    status_code  = Keyword.get(opts, :status_code, 200)

    Bypass.expect_once(bypass, "GET", uri, fn conn ->
      send_json_resp(conn, user_params, status_code)
    end)
  end

  @spec expect_oauth_access_token_request(Bypass.t(), Keyword.t()) :: :ok
  def expect_oauth_access_token_request(bypass, _opts \\ []) do
    Bypass.expect_once(bypass, "POST", "/oauth/access_token", fn conn ->
      token = %{
        oauth_token: "7588892-kagSNqWge8gB1WwE3plnFsJHAZVfxWD7Vb57p0b4&",
        oauth_token_secret: "PbKfYqSryyeKDWz4ebtY3o5ogNLG11WJuZBc9fQrQo"
      }

      conn
      |> Conn.put_resp_content_type("application/x-www-form-urlencoded")
      |> Conn.resp(200, URI.encode_query(token))
    end)
  end

  @spec expect_oauth2_access_token_request(Bypass.t(), Keyword.t(), function() | nil) :: :ok
  def expect_oauth2_access_token_request(bypass, opts \\ [], assert_fn \\ nil) do
    access_token = Keyword.get(opts, :access_token, "access_token")
    token_params = Keyword.get(opts, :params, %{access_token: access_token})
    uri          = Keyword.get(opts, :uri, "/oauth/token")
    status_code  = Keyword.get(opts, :status_code, 200)

    Bypass.expect_once(bypass, "POST", uri, fn conn ->
      if assert_fn, do: assert_fn.(conn)

      send_json_resp(conn, token_params, status_code)
    end)
  end

  @spec expect_oauth2_user_request(Bypass.t(), map(), Keyword.t(), function() | nil) :: :ok
  def expect_oauth2_user_request(bypass, user_params, opts \\ [], assert_fn \\ nil) do
    uri          = Keyword.get(opts, :uri, "/api/user")

    expect_oauth2_api_request(bypass, uri, user_params, opts, assert_fn)
  end

  @spec expect_oauth2_api_request(Bypass.t(), binary(), map(), Keyword.t(), function() | nil) :: :ok
  def expect_oauth2_api_request(bypass, uri, response, opts \\ [], assert_fn \\ nil) do
    access_token = Keyword.get(opts, :access_token, "access_token")
    status_code  = Keyword.get(opts, :status_code, 200)

    Bypass.expect_once(bypass, "GET", uri, fn conn ->
      if assert_fn, do: assert_fn.(conn)

      assert_bearer_token_in_header(conn, access_token)

      send_json_resp(conn, response, status_code)
    end)
  end

  @spec expect_oauth2_flow(Bypass.t(), Keyword.t()) :: :ok
  def expect_oauth2_flow(bypass, opts \\ []) do
    token_params = Keyword.get(opts, :token, %{"access_token" => "access_token"})
    user_params  = Map.merge(%{uid: "new_user", name: "Dan Schultzer"}, Keyword.get(opts, :user, %{}))

    expect_oauth2_access_token_request(bypass, params: token_params)
    expect_oauth2_user_request(bypass, user_params)
  end

  defp assert_bearer_token_in_header(conn, token) do
    expected = {"authorization", "Bearer #{token}"}

    case Enum.find(conn.req_headers, &(elem(&1, 0) == "authorization")) do
      ^expected ->
        true

      {"authorization", "Bearer " <> found_token} ->
        ExUnit.Assertions.flunk("Expected bearer token #{token}, but received #{found_token}")

      _ ->
        ExUnit.Assertions.flunk("No bearer token found in headers")
    end
  end

  defp send_json_resp(conn, body, status_code) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(status_code, Jason.encode!(body))
  end
end
