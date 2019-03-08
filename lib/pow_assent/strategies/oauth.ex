defmodule PowAssent.Strategy.OAuth do
  @moduledoc """
  OAuth 1.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers: [
          example: [
            consumer_key: "REPLACE_WITH_CONSUMER_KEY",
            consumer_secret: "REPLACE_WITH_CONSUMER_SECRET",
            strategy: PowAssent.Strategy.OAuth,
            site: "https://auth.example.com"
          ]
        ]
  """
  @behaviour PowAssent.Strategy

  alias PowAssent.Strategy, as: Helpers
  alias PowAssent.{HTTPAdapter.HTTPResponse, RequestError}

  @doc false
  @spec authorize_url(Keyword.t()) :: {:ok, %{url: binary()}} | {:error, term()}
  def authorize_url(config) do
    config
    |> get_request_token([{"oauth_callback", config[:redirect_uri]}])
    |> build_authorize_url(config)
    |> case do
      {:ok, url}      -> {:ok, %{url: url}}
      {:error, error} -> {:error, error}
    end
  end

  @doc false
  @spec callback(Keyword.t(), map(), atom()) :: {:ok, %{user: map(), token: map()}} | {:error, term()}
  def callback(config, %{"oauth_token" => oauth_token, "oauth_verifier" => oauth_verifier}, strategy \\ __MODULE__) do
    config
    |> get_access_token(oauth_token, oauth_verifier)
    |> fetch_user(config, strategy)
  end

  defp get_request_token(config, params) do
    site              = config[:site]
    request_token_url = process_url(config, config[:request_token_url] || "/oauth/request_token")
    credentials       = OAuther.credentials([
      consumer_key: config[:consumer_key],
      consumer_secret: config[:consumer_secret]])

    config
    |> request(:post, site, request_token_url, credentials, params)
    |> Helpers.decode_response(config)
    |> process_token_response()
  end

  defp build_authorize_url({:ok, token}, config) do
    url = process_url(config, config[:authorize_url] || "/oauth/authenticate")
    url = url <> "?" <> URI.encode_query(%{oauth_token: token["oauth_token"]})

    {:ok, url}
  end
  defp build_authorize_url({:error, error}, _config), do: {:error, error}

  defp get_access_token(config, oauth_token, oauth_verifier) do
    site             = config[:site]
    access_token_url = process_url(config, config[:access_token_url] || "/oauth/access_token")
    params           = [{"oauth_verifier", oauth_verifier}]
    credentials      = OAuther.credentials([
      consumer_key: config[:consumer_key],
      consumer_secret: config[:consumer_secret],
      token: oauth_token])

    config
    |> request(:post, site, access_token_url, credentials, params)
    |> Helpers.decode_response(config)
    |> process_token_response()
  end

  defp request(config, method, site, url, credentials, params) do
    signed_params        = OAuther.sign(Atom.to_string(method), url, params, credentials)
    {header, req_params} = OAuther.header(signed_params)
    headers              = request_headers(method, header)
    body                 = request_body(method, req_params)
    url                  = Helpers.to_url(site, url)

    Helpers.request(method, url, body, headers, config)
  end

  defp request_headers(:post, header), do: [{"content-type", "application/x-www-form-urlencoded"}, header]
  defp request_headers(_method, header), do: [header]

  defp request_body(:post, req_params), do: URI.encode_query(req_params)
  defp request_body(_method, _req_params), do: nil

  defp process_token_response({:ok, %HTTPResponse{status: 200, body: body} = response}) when is_binary(body), do: process_token_response({:ok, %{response | body: URI.decode_query(body)}})
  defp process_token_response({:ok, %HTTPResponse{status: 200, body: %{"oauth_token" => _} = token}}), do: {:ok, token}
  defp process_token_response(any), do: process_response(any)

  defp process_response({:ok, %HTTPResponse{} = response}), do: {:error, RequestError.unexpected(response)}
  defp process_response({:error, %HTTPResponse{} = response}), do: {:error, RequestError.invalid(response)}
  defp process_response({:error, error}), do: {:error, error}

  defp fetch_user({:ok, token}, config, strategy) do
    config
    |> strategy.get_user(token)
    |> case do
      {:ok, user}     -> {:ok, %{user: user, token: token}}
      {:error, error} -> {:error, error}
    end
  end
  defp fetch_user({:error, error}, _config, _strategy),
    do: {:error, error}

  @doc """
  Makes a HTTP get request to the API.

  JSON responses will be decoded to maps.
  """
  @spec get(Keyword.t(), map(), binary(), Keyword.t()) :: {:ok, map()} | {:error, term()}
  def get(config, token, url, params \\ []) do
    site        = config[:site]
    url         = process_url(config, url)
    credentials = OAuther.credentials([
      consumer_key: config[:consumer_key],
      consumer_secret: config[:consumer_secret],
      token: token["oauth_token"],
      token_secret: token["oauth_token_secret"]])

    config
    |> request(:get, site, url, credentials, params)
    |> Helpers.decode_response(config)
  end

  @doc false
  @spec get_user(Keyword.t(), map()) :: {:ok, map()} | {:error, term()}
  def get_user(config, token) do
    config
    |> get(token, config[:user_url])
    |> process_user_response()
  end

  defp process_user_response({:ok, %HTTPResponse{status: 200, body: user}}), do: {:ok, user}
  defp process_user_response({:error, %HTTPResponse{status: 401}}), do: {:error, %RequestError{message: "Unauthorized token"}}
  defp process_user_response(any), do: process_response(any)

  defp process_url(config, url) do
    case String.downcase(url) do
      <<"http://"::utf8, _::binary>>  -> url
      <<"https://"::utf8, _::binary>> -> url
      _                               -> config[:site] <> url
    end
  end
end
