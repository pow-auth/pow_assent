defmodule PowAssent.Strategy.OAuth.Base do
  @moduledoc """
  OAuth 1.0 strategy base.

  ## Usage

      defmodule MyApp.MyOAuthStratey do
        use PowAssent.Strategy.OAuth

        def default_config(_config) do
          [
            site: "https://api.example.com",
            authorize_url: "/authorization/new",
            token_url: "/authorization/token",
            user_url: "/authorization.json",
            authorization_params: [scope: "default"]
          ]
        end

        def normalize(_config, user) do
          {:ok, %{
            "uid"   => user["id"],
            "name"  => user["name"],
            "email" => user["email"]
          }}
        end
      end
  """
  alias PowAssent.Strategy.OAuth
  alias Plug.Conn

  @callback default_config(Keyword.t()) :: Keyword.t()
  @callback normalize(Keyword.t(), map()) :: {:ok, map()} | {:error, any()}

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      use PowAssent.Strategy

      alias PowAssent.Strategy, as: Helpers
      alias Plug.Conn

      @spec authorize_url(Keyword.t(), Conn.t()) :: {:ok, %{conn: Conn.t(), url: binary()}} | {:error, %{conn: Conn.t(), error: any()}}
      def authorize_url(config, conn) do
        config
        |> set_config()
        |> OAuth.authorize_url(conn)
      end

      @spec callback(Keyword.t(), Conn.t(), map()) :: {:ok, %{conn: Conn.t(), user: map()}} | {:error, %{conn: Conn.t(), error: any()}}
      def callback(config, conn, params) do
        config = set_config(config)

        config
        |> OAuth.callback(conn, params)
        |> maybe_normalize(config)
      end

      defp maybe_normalize({:ok, %{user: user} = results}, config) do
        case normalize(config, user) do
          {:ok, user}     -> {:ok, %{results | user: Helpers.prune(user)}}
          {:error, error} -> maybe_normalize({:error, error}, config)
        end
      end
      defp maybe_normalize({:error, error}, _config), do: {:error, error}

      defp set_config(config) do
        config
        |> default_config()
        |> Keyword.merge(config)
      end

      defoverridable unquote(__MODULE__)
    end
  end
end
