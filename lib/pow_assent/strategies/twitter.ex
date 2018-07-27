defmodule PowAssent.Strategy.Twitter do
  @moduledoc """
  Twitter OAuth 1.0 strategy.
  """
  use PowAssent.Strategy

  alias PowAssent.Strategy.OAuth, as: OAuthHelper

  @doc false
  @spec authorize_url(Keyword.t(), Conn.t()) :: {:ok, %{conn: Conn.t(), url: String.t()}}
  def authorize_url(config, conn) do
    config
    |> set_config()
    |> OAuthHelper.authorize_url(conn)
  end

  @doc false
  @spec callback(Keyword.t(), Conn.t(), map()) :: {:ok, %{conn: Conn.t(), user: map()}} | {:error, %{conn: Conn.t(), error: any()}}
  def callback(config, conn, params) do
    config
    |> set_config()
    |> OAuthHelper.callback(conn, params)
    |> normalize()
  end

  defp set_config(config) do
    [
      site: "https://api.twitter.com",
      user_url: "/1.1/account/verify_credentials.json?include_entities=false&skip_status=true&include_email=true",
    ]
    |> Keyword.merge(config)
  end

  defp normalize({:ok, %{conn: conn, user: user}}) do
    user = %{
      "uid"         => Integer.to_string(user["id"]),
      "nickname"    => user["screen_name"],
      "email"       => user["email"],
      "location"    => user["location"],
      "name"        => user["name"],
      "image"       => user["profile_image_url_https"],
      "description" => user["description"],
      "urls"        => %{"Website" => user["url"],
                        "Twitter" => "https://twitter.com/#{user["screen_name"]}"}}

    {:ok, %{conn: conn, user: Helpers.prune(user)}}
  end
  defp normalize({:error, error}), do: {:error, error}
end
