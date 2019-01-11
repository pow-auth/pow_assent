defmodule PowAssent.Strategy.OAuth2.Base do
  @moduledoc """
  OAuth 2.0 strategy base.

  ## Usage

      defmodule MyApp.MyOAuth2Strategy do
        use PowAssent.Strategy.OAuth2

        def default_config(_config) do
          [
            site: "https://api.example.com",
            user_url: "/authorization.json"
          ]
        end

        def normalize(_config, user) do
          %{
            "uid"         => user["id"],
            "name"        => user["name"],
            "email"       => user["email"]
          }
        end
      end
  """
  alias PowAssent.Strategy.OAuth2
  alias Plug.Conn

  @callback default_config(Keyword.t()) :: Keyword.t()
  @callback normalize(Keyword.t(), map()) :: {:ok, map()} | {:error, any()}
  @callback get_user(Keyword.t(), map()) :: {:ok, map()} | {:error, any()}

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      use PowAssent.Strategy

      alias PowAssent.Strategy, as: Helpers
      alias Plug.Conn

      @spec authorize_url(Keyword.t(), Conn.t()) :: {:ok, %{conn: Conn.t(), state: binary(), url: binary()}}
      def authorize_url(config, conn) do
        config
        |> set_config()
        |> OAuth2.authorize_url(conn)
      end

      @spec callback(Keyword.t(), Conn.t(), map()) :: {:ok, %{conn: Conn.t(), user: map()}} | {:error, %{conn: Conn.t(), error: any()}}
      def callback(config, conn, params) do
        config = set_config(config)

        config
        |> OAuth2.callback(conn, params, __MODULE__)
        |> maybe_normalize(config)
      end

      @spec get_user(Keyword.t(), map()) :: {:ok, map()} | {:error, any()}
      def get_user(config, token), do: OAuth2.get_user(config, token)

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
        |> Keyword.put(:strategy, __MODULE__)
      end

      defoverridable unquote(__MODULE__)
    end
  end
end
