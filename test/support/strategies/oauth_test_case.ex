defmodule PowAssent.Test.OAuthTestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  setup _context do
    params = %{"oauth_token" => "test", "oauth_verifier" => "test"}
    bypass = Bypass.open()
    config = [site: "http://localhost:#{bypass.port}"]

    {:ok, callback_params: params, config: config, bypass: bypass}
  end

  using do
    quote do
      use ExUnit.Case

      import unquote(__MODULE__)
    end
  end

  alias Plug.Conn

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
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(status_code, Jason.encode!(user_params))
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
end
