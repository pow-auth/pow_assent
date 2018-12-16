defmodule PowAssent.Strategy.Instagram do
  @moduledoc """
  Instagram OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers:
            [
              instagram: [
                client_id: "REPLACE_WITH_CLIENT_ID",
                client_secret: "REPLACE_WITH_CLIENT_SECRET",
                strategy: PowAssent.Strategy.Instagram
              ]
            ]
  """
  use PowAssent.Strategy.OAuth2.Base

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(_config) do
    [
      site: "https://api.instagram.com",
      authorization_params: [scope: "basic"],
      get_user_fn: &get_user/2
    ]
  end

  @spec normalize(Keyword.t(), map()) :: {:ok, map()}
  def normalize(_config, user) do
    {:ok, %{
      "uid"      => user["id"],
      "name"     => user["full_name"],
      "image"    => user["profile_picture"],
      "nickname" => user["username"]}}
  end

  @spec get_user(Keyword.t(), Client.t()) :: {:ok, map()}
  def get_user(_config, client) do
    {:ok, client.token.other_params["user"]}
  end
end
