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
    config = set_config(config)
    client = Client.new(config)
    state  = conn.private[:pow_assent_state]

    state
    |> OAuth2Helper.check_state(client, params)
    |> OAuth2Helper.get_access_token(config, params)
    |> parse_user(conn)
    |> normalize()
  end

  defp set_config(config) do
    [
      site: "https://api.instagram.com",
      authorization_params: [scope: "basic"]
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, AuthCode)
  end

  defp parse_user({:ok, client}, conn) do
    {:ok, %{conn: conn, user: client.token.other_params["user"], client: client}}
  end
  defp parse_user({:error, error}, _conn), do: {:error, error}

  defp normalize({:ok, %{conn: conn, user: user, client: client}}) do
    user = %{
      "uid"      => user["id"],
      "name"     => user["full_name"],
      "image"    => user["profile_picture"],
      "nickname" => user["username"]
    }

    {:ok, %{conn: conn, user: Helpers.prune(user), client: client}}
  end
  defp normalize({:error, error}), do: {:error, error}
end
