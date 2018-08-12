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
end
