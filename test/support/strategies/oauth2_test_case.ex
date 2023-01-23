defmodule PowAssent.Test.OAuth2TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  setup do
    TestServer.start(scheme: :https)

    params = %{"code" => "test", "state" => "test"}
    config = [client_secret: "secret", site: TestServer.url(), session_params: %{state: "test"}]

    {:ok, callback_params: params, config: config}
  end

  using do
    quote do
      use ExUnit.Case

      import unquote(__MODULE__)
    end
  end

  alias Plug.Conn

  @spec add_oauth2_access_token_endpoint(Keyword.t(), function() | nil) :: :ok
  def add_oauth2_access_token_endpoint(opts \\ [], assert_fn \\ nil) do
    access_token = Keyword.get(opts, :access_token, "access_token")
    token_params = Keyword.get(opts, :params, %{access_token: access_token})
    uri          = Keyword.get(opts, :uri, "/oauth/token")
    status_code  = Keyword.get(opts, :status_code, 200)

    TestServer.add(uri, via: :post, to: fn conn ->
      if assert_fn, do: assert_fn.(conn)

      send_json_resp(conn, token_params, status_code)
    end)
  end

  @spec add_oauth2_user_endpoint(map(), Keyword.t(), function() | nil) :: :ok
  def add_oauth2_user_endpoint(user_params, opts \\ [], assert_fn \\ nil) do
    uri = Keyword.get(opts, :uri, "/api/user")

    add_oauth2_api_endpoint(uri, user_params, opts, assert_fn)
  end

  @spec add_oauth2_api_endpoint(binary(), map(), Keyword.t(), function() | nil) :: :ok
  def add_oauth2_api_endpoint(uri, response, opts \\ [], assert_fn \\ nil) do
    access_token = Keyword.get(opts, :access_token, "access_token")
    status_code  = Keyword.get(opts, :status_code, 200)

    TestServer.add(uri, to: fn conn ->
      if assert_fn, do: assert_fn.(conn)

      assert_bearer_token_in_header(conn, access_token)

      send_json_resp(conn, response, status_code)
    end)
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
