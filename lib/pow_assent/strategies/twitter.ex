defmodule PowAssent.Strategy.Twitter do
  @moduledoc """
  Twitter OAuth 1.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers: [
          twitter: [
            consumer_key: "REPLACE_WITH_CONSUMER_KEY",
            consumer_secret: "REPLACE_WITH_CONSUMER_SECRET",
            strategy: PowAssent.Strategy.Twitter
          ]
        ]
  """
  use PowAssent.Strategy.OAuth.Base

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(_config) do
    [
      site: "https://api.twitter.com",
      user_url: "/1.1/account/verify_credentials.json?include_entities=false&skip_status=true&include_email=true",
    ]
  end

  @spec normalize(Keyword.t(), map()) :: {:ok, map()}
  def normalize(_config, user) do
    {:ok, %{
      "uid"         => Integer.to_string(user["id"]),
      "nickname"    => user["screen_name"],
      "email"       => user["email"],
      "location"    => user["location"],
      "name"        => user["name"],
      "image"       => user["profile_image_url_https"],
      "description" => user["description"],
      "urls"        => %{"Website" => user["url"],
                        "Twitter" => "https://twitter.com/#{user["screen_name"]}"}}}
  end
end
