defmodule PowAssent.Strategy.Slack do
  @moduledoc """
  Slack OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers:
            [
              slack: [
                client_id: "REPLACE_WITH_CLIENT_ID",
                client_secret: "REPLACE_WITH_CLIENT_SECRET",
                strategy: PowAssent.Strategy.Slack
              ]
            ]

  By default, the user can decide what team should be used for authorization.
  If you want to limit to a specific team, please pass a team id to the
  configuration:

      config :my_app, :pow_assent,
        providers:
            [
              slack: [
                client_id: "REPLACE_WITH_CLIENT_ID",
                client_secret: "REPLACE_WITH_CLIENT_SECRET",
                strategy: PowAssent.Strategy.Slack,
                team_id: "XXXXXXX"
              ]
            ]

  This value will be not be used if you set a `authorization_params` key.
  Instead you should set `team: TEAM_ID` in the `authorization_params` keyword
  list.
  """
  use PowAssent.Strategy

  alias PowAssent.Strategy.OAuth2, as: OAuth2Helper
  alias OAuth2.{Client, Strategy.AuthCode}

  @spec authorize_url(Keyword.t(), Conn.t()) :: {:ok, %{conn: Conn.t(), state: binary(), url: binary()}}
  def authorize_url(config, conn) do
    config
    |> set_config()
    |> OAuth2Helper.authorize_url(conn)
  end

  @spec callback(Keyword.t(), Conn.t(), map()) :: {:ok, %{client: Client.t(), conn: Conn.t(), user: map()}} | {:error, %{conn: Conn.t(), error: any()}}
  def callback(config, conn, params) do
    config
    |> set_config()
    |> OAuth2Helper.callback(conn, params)
    |> normalize()
  end

  defp set_config(config) do
    [
      site: "https://slack.com",
      token_url: "/api/oauth.access",
      user_url: "/api/users.identity",
      team_url: "/api/team.info",
      authorization_params: [scope: "identity.basic identity.email identity.avatar", team: config[:team_id]]
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, AuthCode)
  end

  defp normalize({:ok, %{conn: conn, user: identity, client: client}}) do
    user = %{
      "uid"       => uid(identity),
      "name"      => identity["user"]["name"],
      "email"     => identity["user"]["email"],
      "image"     => identity["user"]["image_48"],
      "team_name" => identity["team"]["name"]}

    {:ok, %{conn: conn, user: Helpers.prune(user), client: client}}
  end
  defp normalize({:error, error}), do: {:error, error}

  defp uid(%{"user" => %{"id" => id}, "team" => %{"id" => team_id}}), do: "#{id}-#{team_id}"
end
