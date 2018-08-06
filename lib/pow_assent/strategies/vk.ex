defmodule PowAssent.Strategy.VK do
  @moduledoc """
  VK.com OAuth 2.0 strategy.
  """
  use PowAssent.Strategy

  alias PowAssent.Strategy.OAuth2, as: OAuth2Helper
  alias OAuth2.Client

  @profile_fields ["uid", "first_name", "last_name", "photo_200", "screen_name", "verified"]
  @url_params     %{"fields" => Enum.join(@profile_fields, ","), "v" => "5.69", "https" => "1"}

  @spec authorize_url(Keyword.t(), Conn.t()) :: {:ok, %{conn: Conn.t(), state: binary(), url: binary()}}
  def authorize_url(config, conn) do
    config
    |> set_config()
    |> OAuth2Helper.authorize_url(conn)
  end

  @spec callback(Keyword.t(), Conn.t(), map()) :: {:ok, %{client: Client.t(), conn: Conn.t(), user: map()}} | {:error, %{conn: Conn.t(), error: any()}}
  def callback(config, conn, params) do
    config = set_config(config)
    client = Client.new(config)
    state  = conn.private[:pow_assent_state]

    state
    |> OAuth2Helper.check_state(client, params)
    |> OAuth2Helper.get_access_token(config, params)
    |> get_user(config)
    |> normalize()
    |> case do
      {:ok, user}     -> {:ok, %{conn: conn, user: user, client: client}}
      {:error, error} -> {:error, %{conn: conn, error: error}}
    end
  end

  defp set_config(config) do
    params          = config[:user_url_params] || %{}
    user_url_params = Map.merge(@url_params, params)

    [
      site: "https://api.vk.com",
      authorize_url: "https://oauth.vk.com/authorize",
      token_url: "https://oauth.vk.com/access_token",
      user_url: "/method/users.get",
      authorization_params: [scope: "email"],
      user_url_params: user_url_params
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, OAuth2.Strategy.AuthCode)
  end

  defp get_user({:ok, client}, config) do
    params          = config[:user_url_params] || %{}
    user_url_params = Map.put(params, "access_token", client.token.access_token)
    user_url        = config[:user_url] <> "?" <> URI.encode_query(user_url_params)

    {:ok, client}
    |> OAuth2Helper.get_user(user_url)
    |> get_response(client)
  end
  defp get_user({:error, error}, _config), do: {:error, error}

  defp get_response({:ok, %{"response" => [user]}}, client) do
    email = Map.get(client.token.other_params, "email")
    user  = Map.put_new(user, "email", email)

    {:ok, user}
  end
  defp get_response({:ok, user}, _client),
    do: {:error, %PowAssent.RequestError{message: "Retrieved invalid response: #{inspect user}"}}
  defp get_response({:error, error}, _client),
    do: {:error, error}

  defp normalize({:ok, user}) do
    user = %{
      "uid"         => user["id"] |> to_string,
      "nickname"    => user["screen_name"],
      "first_name"  => user["first_name"],
      "last_name"   => user["last_name"],
      "name"        => [user["first_name"], user["last_name"]] |> Enum.join(" "),
      "email"       => user["email"],
      "image"       => user["photo_200"],
      "verified"    => user["verified"] > 0}

    {:ok, Helpers.prune(user)}
  end
  defp normalize({:error, error}), do: {:error, error}
end
