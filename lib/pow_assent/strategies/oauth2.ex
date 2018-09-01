defmodule PowAssent.Strategy.OAuth2 do
  @moduledoc """
  OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers:
            [
              example: [
                client_id: "REPLACE_WITH_CLIENT_ID",
                client_secret: "REPLACE_WITH_CLIENT_SECRET",
                strategy: PowAssent.Strategy.OAuth2,
                site: "https://auth.example.com",
                authorization_params: [scope: "user:read user:write"],
                user_url: "https://example.com/api/user"
              ]
            ]
  """
  use PowAssent.Strategy

  alias Plug.Conn
  alias OAuth2.{Client, Response}
  alias PowAssent.{CallbackCSRFError, CallbackError, ConfigurationError, RequestError}

  @doc false
  @spec authorize_url(Keyword.t(), Conn.t()) :: {:ok, %{conn: Conn.t(), state: binary(), url: binary()}}
  def authorize_url(config, conn) do
    state        = gen_state()
    conn         = Conn.put_private(conn, :pow_assent_state, state)
    redirect_uri = config[:redirect_uri]
    params       = authorization_params(config, state: state, redirect_uri: redirect_uri)
    url          =
      config
      |> Client.new()
      |> Client.authorize_url!(params)

    {:ok, %{conn: conn, url: url, state: state}}
  end

  defp authorization_params(config, params) do
    config
    |> Keyword.get(:authorization_params, [])
    |> Keyword.merge(params)
  end

  @doc false
  @spec callback(Keyword.t(), Conn.t(), map()) :: {:ok, %{client: Client.t(), conn: Conn.t(), user: map()}} | {:error, %{conn: Conn.t(), error: any()}}
  def callback(config, conn, params) do
    client = Client.new(config)
    state  = conn.private[:pow_assent_state]

    state
    |> check_state(client, params)
    |> get_access_token(config, params)
    |> fetch_user(config, conn)
  end

  @doc false
  @spec check_state(binary(), Client.t(), map) :: {:ok, %{client: Client.t()}} | {:error, any()}
  def check_state(_state, _client, %{"error" => _} = params) do
    message   = params["error_description"] || params["error_reason"] || params["error"]
    error     = params["error"]
    error_uri = params["error_uri"]

    {:error, %CallbackError{message: message, error: error, error_uri: error_uri}}
  end
  def check_state(state, client, %{"code" => _code} = params) do
    case params["state"] do
      ^state -> {:ok, %{client: client}}
      _      -> {:error, %CallbackCSRFError{}}
    end
  end

  @doc false
  @spec get_access_token({:ok, %{client: Client.t()}} | {:error, map()}, Keyword.t(), map()) :: {:ok, Client.t()} | {:error, term()}
  def get_access_token({:ok, %{client: client}}, config, %{"code" => code, "redirect_uri" => redirect_uri}) do
    params = authorization_params(config, code: code, client_secret: client.client_secret, redirect_uri: redirect_uri)

    client
    |> Client.get_token(params)
    |> process_access_token_response()
  end
  def get_access_token({:error, error}, _params, _token_params), do: {:error, error}

  defp process_access_token_response({:ok, %Client{token: %{other_params: %{"error" => error, "error_description" => error_description}}}}),
    do: {:error, %RequestError{message: error_description, error: error}}
  defp process_access_token_response({:error, %Response{body: %{"error" => error}}}),
    do: {:error, %RequestError{message: error}}
  defp process_access_token_response({:ok, client}),
    do: {:ok, client}
  defp process_access_token_response({:error, error}),
    do: {:error, error}

  defp fetch_user({:ok, client}, config, conn) do
    get_user_fn = Keyword.get(config, :get_user_fn, &get_user/2)

    config
    |> get_user_fn.(client)
    |> case do
      {:ok, user} -> {:ok, %{conn: conn, client: client, user: user}}
      {:error, error} -> {:error, %{conn: conn, error: error}}
    end
  end
  defp fetch_user({:error, error}, _user_url, conn),
    do: {:error, %{conn: conn, error: error}}

  @spec get_user(Keyword.t(), Client.t()) :: {:ok, map()} | {:error, term()}
  def get_user(config, client) do
    case config[:user_url] do
      nil ->
        {:error, %ConfigurationError{message: "No user URL set"}}

      url ->
        client
        |> Client.get(url)
        |> process_user_response()
    end
  end

  defp process_user_response({:ok, %Response{body: user}}), do: {:ok, user}
  defp process_user_response({:error, %Response{status_code: 401}}),
    do: {:error, %RequestError{message: "Unauthorized token"}}
  defp process_user_response({:error, error}), do: {:error, error}

  defp gen_state do
    24
    |> :crypto.strong_rand_bytes()
    |> :erlang.bitstring_to_list()
    |> Enum.map(fn x -> :erlang.integer_to_binary(x, 16) end)
    |> Enum.join()
    |> String.downcase()
  end
end
