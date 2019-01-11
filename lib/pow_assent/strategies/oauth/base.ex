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
  alias PowAssent.Strategy, as: Helpers
  alias PowAssent.Strategy.OAuth
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

      @spec authorize_url(Keyword.t(), Conn.t()) :: {:ok, %{conn: Conn.t(), url: binary()}} | {:error, %{conn: Conn.t(), error: any()}}
      def authorize_url(config, conn), do: unquote(__MODULE__).authorize_url(config, conn, __MODULE__)

      @spec callback(Keyword.t(), Conn.t(), map()) :: {:ok, %{conn: Conn.t(), user: map()}} | {:error, %{conn: Conn.t(), error: any()}}
      def callback(config, conn, params), do: unquote(__MODULE__).callback(config, conn, params, __MODULE__)

      @spec get_user(Keyword.t(), map()) :: {:ok, map()} | {:error, any()}
      def get_user(config, token), do: OAuth.get_user(config, token)

      defoverridable unquote(__MODULE__)
    end
  end


  @spec authorize_url(Keyword.t(), Conn.t(), module()) :: {:ok, %{conn: Conn.t(), url: binary()}} | {:error, %{conn: Conn.t(), error: any()}}
  def authorize_url(config, conn, strategy) do
    config
    |> set_config(strategy)
    |> OAuth.authorize_url(conn)
  end

  @spec callback(Keyword.t(), Conn.t(), map(), module()) :: {:ok, %{conn: Conn.t(), user: map()}} | {:error, %{conn: Conn.t(), error: any()}}
  def callback(config, conn, params, strategy) do
    config = set_config(config, strategy)

    config
    |> OAuth.callback(conn, params, strategy)
    |> normalize(config, strategy)
  end

  defp normalize({:ok, %{user: user} = results}, config, strategy) do
    case strategy.normalize(config, user) do
      {:ok, user}     -> {:ok, %{results | user: Helpers.prune(user)}}
      {:error, error} -> normalize({:error, error}, config, strategy)
    end
  end
  defp normalize({:error, error}, _config, _strategy), do: {:error, error}

  defp set_config(config, strategy) do
    config
    |> strategy.default_config()
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, strategy)
  end
end
