defmodule OAuth2.TestHelpers do
  @moduledoc false

  @spec bypass_server(%Bypass{}) :: String.t()
  def bypass_server(%Bypass{port: port}) do
    "http://localhost:#{port}"
  end

  @spec assert_access_token_in_header(Plug.Conn.t(), String.t()) :: true | no_return
  def assert_access_token_in_header(conn, token) do
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

  @spec setup_strategy_env(%Bypass{}) :: :ok
  def setup_strategy_env(server) do
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

  @spec bypass_oauth(%Bypass{}, map(), map()) :: :ok
  def bypass_oauth(server, token_params \\ %{}, user_params \\ %{}) do
    Bypass.expect_once(server, "POST", "/oauth/token", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(Map.merge(%{access_token: "access_token"}, token_params)))
    end)

    Bypass.expect_once(server, "GET", "/api/user", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(Map.merge(%{uid: "1", name: "Dan Schultzer"}, user_params)))
    end)
  end
end
