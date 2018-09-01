defmodule PowAssent.Strategy.VK do
  @moduledoc """
  VK.com OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers:
            [
              vk: [
                client_id: "REPLACE_WITH_CLIENT_ID",
                client_secret: "REPLACE_WITH_CLIENT_SECRET",
                strategy: PowAssent.Strategy.VK
              ]
            ]
  """
  use PowAssent.Strategy.OAuth2.Base

  alias PowAssent.Strategy.OAuth2

  @profile_fields ["uid", "first_name", "last_name", "photo_200", "screen_name", "verified"]
  @url_params     %{"fields" => Enum.join(@profile_fields, ","), "v" => "5.69", "https" => "1"}

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(config) do
    params          = config[:user_url_params] || %{}
    user_url_params = Map.merge(@url_params, params)

    [
      site: "https://api.vk.com",
      authorize_url: "https://oauth.vk.com/authorize",
      token_url: "https://oauth.vk.com/access_token",
      user_url: "/method/users.get",
      authorization_params: [scope: "email"],
      user_url_params: user_url_params,
      get_user_fn: &get_user/2
    ]
  end

  @spec normalize(Client.t(), Keyword.t(), map()) :: {:ok, map()}
  def normalize(_client, _config, user) do
    {:ok, %{
      "uid"         => to_string(user["id"]),
      "nickname"    => user["screen_name"],
      "first_name"  => user["first_name"],
      "last_name"   => user["last_name"],
      "name"        => Enum.join([user["first_name"], user["last_name"]], " "),
      "email"       => user["email"],
      "image"       => user["photo_200"],
      "verified"    => user["verified"] > 0}}
  end

  @spec get_user(Keyword.t(), Client.t()) :: {:ok, map()} | {:error, any()}
  defp get_user(config, client) do
    params = Keyword.get(config, :user_url_params, %{})
    config = Keyword.put(config, :user_url, user_url(config, client, params))

    config
    |> OAuth2.get_user(client)
    |> handle_user_response(client)
  end

  defp user_url(config, client, params) do
    user_url_params = Map.put(params, "access_token", client.token.access_token)

    config[:user_url] <> "?" <> URI.encode_query(user_url_params)
  end

  defp handle_user_response({:ok, %{"response" => [user]}}, client) do
    email = Map.get(client.token.other_params, "email")
    user  = Map.put_new(user, "email", email)

    {:ok, user}
  end
  defp handle_user_response({:ok, user}, _client),
    do: {:error, %PowAssent.RequestError{message: "Retrieved invalid response: #{inspect user}"}}
  defp handle_user_response({:error, error}, _client),
    do: {:error, error}
end
