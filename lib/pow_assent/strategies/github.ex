defmodule PowAssent.Strategy.Github do
  @moduledoc """
  Github OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers:
            [
              github: [
                client_id: "REPLACE_WITH_CLIENT_ID",
                client_secret: "REPLACE_WITH_CLIENT_SECRET",
                strategy: PowAssent.Strategy.Github
              ]
            ]
  """
  use PowAssent.Strategy.OAuth2.Base

  alias OAuth2.{Client, Response}
  alias PowAssent.Strategy.OAuth2

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(_config) do
    [
      site: "https://api.github.com",
      authorize_url: "https://github.com/login/oauth/authorize",
      token_url: "https://github.com/login/oauth/access_token",
      user_url: "/user",
      user_emails_url: "/user/emails",
      authorization_params: [scope: "read:user,user:email"],
      get_user_fn: &get_user/2
    ]
  end

  @spec normalize(Keyword.t(), map()) :: {:ok, map()} | {:error, any()}
  def normalize(_config, user) do
    {:ok, %{
      "uid"      => Integer.to_string(user["id"]),
      "nickname" => user["login"],
      "email"    => user["email"],
      "name"     => user["name"],
      "image"    => user["avatar_url"],
      "urls"     => %{
        "GitHub" => user["html_url"],
        "Blog"   => user["blog"]}}}
  end

  @spec get_user(Keyword.t(), Client.t()) :: {:ok, map()} | {:error, any()}
  def get_user(config, client) do
    config
    |> OAuth2.get_user(client)
    |> get_email(client, config)
  end

  defp get_email({:ok, user}, client, config) do
    client
    |> Client.get(config[:user_emails_url])
    |> process_get_email_response(user)
  end
  defp get_email({:error, error}, _client, _config), do: {:error, error}

  defp process_get_email_response({:ok, %Response{body: emails}}, user) do
    email = get_primary_email(emails)

    {:ok, Map.put(user, "email", email)}
  end
  defp process_get_email_response({:error, error}, _user), do: {:error, error}

  defp get_primary_email([%{"verified" => true, "primary" => true, "email" => email} | _rest]),
    do: email
  defp get_primary_email(_any), do: nil
end
