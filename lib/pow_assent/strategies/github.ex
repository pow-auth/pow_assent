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
  use PowAssent.Strategy

  alias PowAssent.Strategy.OAuth2, as: OAuth2Helper
  alias OAuth2.{Client, Response, Strategy.AuthCode}

  @spec authorize_url(Keyword.t(), Conn.t()) :: {:ok, %{conn: Conn.t(), state: binary(), url: binary()}}
  def authorize_url(config, conn) do
    config
    |> set_config()
    |> OAuth2Helper.authorize_url(conn)
  end

  @spec callback(Keyword.t(), Conn.t(), map()) :: {:ok, %{client: Client.t(), conn: Conn.t(), user: map()}} | {:error, %{conn: Conn.t(), error: any()}}
  def callback(config, conn, params) do
    config = set_config(config)

    config
    |> OAuth2Helper.callback(conn, params)
    |> get_email(config)
    |> normalize()
  end

  defp set_config(config) do
    [
      site: "https://api.github.com",
      authorize_url: "https://github.com/login/oauth/authorize",
      token_url: "https://github.com/login/oauth/access_token",
      user_url: "/user",
      user_emails_url: "/user/emails",
      authorization_params: [scope: "read:user,user:email"]
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, AuthCode)
  end

  defp get_email({:ok, %{conn: conn, user: user, client: client}}, config) do
    case Client.get(client, config[:user_emails_url]) do
      {:ok, %Response{body: emails}} ->
        user = Map.put(user, "email", get_primary_email(emails))
        {:ok, %{conn: conn, user: user, client: client}}

      {:error, error} ->
        {:error, %{conn: conn, error: error}}
    end
  end
  defp get_email(response, _config), do: response

  defp get_primary_email(emails) do
    emails
    |> Enum.find(%{}, fn(element) -> element["primary"] && element["verified"] end)
    |> Map.fetch("email")
    |> case do
      {:ok, email} -> email
      :error       -> nil
    end
  end

  defp normalize({:ok, %{conn: conn, user: user, client: client}}) do
    user = %{
      "uid"      => Integer.to_string(user["id"]),
      "nickname" => user["login"],
      "email"    => user["email"],
      "name"     => user["name"],
      "image"    => user["avatar_url"],
      "urls"     => %{
        "GitHub" => user["html_url"],
        "Blog"   => user["blog"]}}

    {:ok, %{conn: conn, user: Helpers.prune(user), client: client}}
  end
  defp normalize({:error, error}), do: {:error, error}
end
