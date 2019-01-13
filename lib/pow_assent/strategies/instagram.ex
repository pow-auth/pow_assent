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
      authorization_params: [scope: "basic"]
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

  @spec get_user(Keyword.t(), map()) :: {:ok, map()}
  def get_user(_config, token) do
    {:ok, token["user"]}
  end
end
