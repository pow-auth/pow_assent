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

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(_config) do
    [
      site: "https://api.github.com",
      authorize_url: "https://github.com/login/oauth/authorize",
      token_url: "https://github.com/login/oauth/access_token",
      user_url: "/user",
      user_emails_url: "/user/emails",
      authorization_params: [scope: "read:user,user:email"]
    ]
  end

  @spec normalize(Client.t(), Keyword.t(), map()) :: {:ok, map()} | {:error, any()}
  def normalize(client, config, user) do
    case get_email(client, config) do
      {:ok, email} ->
        {:ok, %{
          "uid"      => Integer.to_string(user["id"]),
          "nickname" => user["login"],
          "email"    => email,
          "name"     => user["name"],
          "image"    => user["avatar_url"],
          "urls"     => %{
            "GitHub" => user["html_url"],
            "Blog"   => user["blog"]}}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_email(client, config) do
    case Client.get(client, config[:user_emails_url]) do
      {:ok, %Response{body: emails}} -> {:ok, get_primary_email(emails)}
      {:error, error}                -> {:error, error}
    end
  end

  defp get_primary_email(emails) do
    emails
    |> Enum.find(%{}, fn(element) -> element["primary"] && element["verified"] end)
    |> Map.fetch("email")
    |> case do
      {:ok, email} -> email
      :error       -> nil
    end
  end
end
