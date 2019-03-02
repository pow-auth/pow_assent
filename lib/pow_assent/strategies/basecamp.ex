defmodule PowAssent.Strategy.Basecamp do
  @moduledoc """
  Basecamp OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers: [
          basecamp: [
            client_id: "REPLACE_WITH_CLIENT_ID",
            client_secret: "REPLACE_WITH_CLIENT_SECRET",
            strategy: PowAssent.Strategy.Basecamp
          ]
        ]
  """
  use PowAssent.Strategy.OAuth2.Base

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(_config) do
    [
      site: "https://launchpad.37signals.com",
      authorize_url: "/authorization/new",
      token_url: "/authorization/token",
      user_url: "/authorization.json",
      authorization_params: [type: "web_server"]
    ]
  end

  @spec normalize(Keyword.t(), map()) :: {:ok, map()}
  def normalize(_config, user) do
    {:ok, %{
      "uid"        => Integer.to_string(user["identity"]["id"]),
      "name"       => "#{user["identity"]["first_name"]} #{user["identity"]["last_name"]}",
      "first_name" => user["identity"]["first_name"],
      "last_name"  => user["identity"]["last_name"],
      "email"      => user["identity"]["email_address"],
      "accounts"   => user["accounts"]
    }}
  end
end
