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
  use PowAssent.Strategy.OAuth2.Base

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(config) do
    [
      site: "https://slack.com",
      token_url: "/api/oauth.access",
      user_url: "/api/users.identity",
      team_url: "/api/team.info",
      authorization_params: [scope: "identity.basic identity.email identity.avatar", team: config[:team_id]]
    ]
  end

  @spec normalize(Keyword.t(), map()) :: {:ok, map()}
  def normalize(_config, identity) do
    {:ok, %{
      "uid"       => uid(identity),
      "name"      => identity["user"]["name"],
      "email"     => identity["user"]["email"],
      "image"     => identity["user"]["image_48"],
      "team_name" => identity["team"]["name"]}}
  end

  defp uid(%{"user" => %{"id" => id}, "team" => %{"id" => team_id}}), do: "#{id}-#{team_id}"
end
