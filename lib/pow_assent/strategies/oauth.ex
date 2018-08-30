defmodule PowAssent.Strategy.OAuth do
  @moduledoc """
  OAuth 1.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers:
            [
              example: [
                consumer_key: "REPLACE_WITH_CONSUMER_KEY",
                consumer_secret: "REPLACE_WITH_CONSUMER_SECRET",
                strategy: PowAssent.Strategy.OAuth,
                site: "https://auth.example.com"
              ]
            ]
  """
  use PowAssent.Strategy

  @doc false
  @spec authorize_url(Keyword.t(), Conn.t()) :: {:ok, %{conn: Conn.t(), url: binary()}} | {:error, %{conn: Conn.t(), error: any()}}
  def authorize_url(config, conn) do
    config
    |> get_request_token([{"oauth_callback", config[:redirect_uri]}])
    |> build_authorize_url(config)
    |> case do
      {:ok, url}     -> {:ok, %{conn: conn, url: url}}
      {:error, term} -> {:error, %{conn: conn, error: term}}
    end
  end

  @doc false
  @spec callback(Keyword.t(), Conn.t(), map()) :: {:ok, %{conn: Conn.t(), user: map}} | {:error, %{conn: Conn.t(), error: any()}}
  def callback(config, conn, %{"oauth_token" => oauth_token, "oauth_verifier" => oauth_verifier}) do
    config
    |> get_access_token(oauth_token, oauth_verifier)
    |> get_user(config)
    |> case do
      {:ok, user}    -> {:ok, %{conn: conn, user: user}}
      {:error, error} -> {:error, %{conn: conn, error: error}}
    end
  end

  defp get_request_token(config, params) do
    site              = config[:site]
    request_token_url = process_url(config, config[:request_token_url] || "/oauth/request_token")
    credentials       = OAuther.credentials([
      consumer_key: config[:consumer_key],
      consumer_secret: config[:consumer_secret]])

    :post
    |> request(site, request_token_url, credentials, params)
    |> process_request_token_response()
  end

  defp build_authorize_url({:ok, token}, config) do
    url = process_url(config, config[:authorize_url] || "/oauth/authenticate")
    url = url <> "?" <> URI.encode_query(%{oauth_token: token["oauth_token"]})

    {:ok, url}
  end
  defp build_authorize_url({:error, error}, _config), do: {:error, error}

  @doc false
  @spec get_access_token(Keyword.t(), binary(), binary()) :: {:ok, map} | {:error, term}
  def get_access_token(config, oauth_token, oauth_verifier) do
    site             = config[:site]
    access_token_url = process_url(config, config[:access_token_url] || "/oauth/access_token")
    params           = [{"oauth_verifier", oauth_verifier}]
    credentials      = OAuther.credentials([
      consumer_key: config[:consumer_key],
      consumer_secret: config[:consumer_secret],
      token: oauth_token])

    :post
    |> request(site, access_token_url, credentials, params)
    |> process_request_token_response()
  end

  defp request(method, site, url, credentials, params \\ [], body \\ "") do
    signed_params        = OAuther.sign(Atom.to_string(method), url, params, credentials)
    {header, req_params} = OAuther.header(signed_params)
    client               = %OAuth2.Client{site: site}

    method
    |> OAuth2.Request.request(client, url, body, [header], [form: req_params])
    |> case do
      {:ok, response} -> {:ok, response.body}
      {:error, error} -> {:error, error}
    end
  end

  defp process_request_token_response({:ok, body}) do
    {:ok, URI.decode_query(body)}
  end
  defp process_request_token_response({:error, error}), do: {:error, error}

  @doc false
  @spec get_user({:ok, map} | {:error, term}, Keyword.t()) :: {:ok, map} | {:error, term}
  def get_user({:ok, token}, config) do
    site        = config[:site]
    url         = process_url(config, config[:user_url])
    credentials = OAuther.credentials([
      consumer_key: config[:consumer_key],
      consumer_secret: config[:consumer_secret],
      token: token["oauth_token"],
      token_secret: token["oauth_token_secret"]])

    request(:get, site, url, credentials)
  end
  def get_user({:error, error}, _config), do: {:error, error}

  defp process_url(config, url) do
    case String.downcase(url) do
      <<"http://"::utf8, _::binary>>  -> url
      <<"https://"::utf8, _::binary>> -> url
      _                               -> config[:site] <> url
    end
  end
end
