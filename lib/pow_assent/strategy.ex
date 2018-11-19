defmodule PowAssent.Strategy do
  @moduledoc """
  Used for creating strategies.

  ## Usage

  Set up `my_strategy.ex` the following way:

      defmodule MyStrategy do
        use PowAssent.Strategy

        def authorize_url(config, conn) do
          # generate authorization url
        end

        def callback(config, conn, params) do
          # return normalized user params map
        end
      end
  """
  alias Plug.Conn

  @callback authorize_url(Keyword.t(), Conn.t()) ::
              {:ok, %{:conn => Conn.t(), :url => binary(), optional(atom()) => any()}}
              | {:error, %{conn: Conn.t(), error: any()}}
  @callback callback(Keyword.t(), Conn.t(), map()) ::
              {:ok, %{:conn => Conn.t(), :user => map(), optional(atom()) => any()}}
              | {:error, %{conn: Conn.t(), error: any()}}

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end

  @doc """
  Recursively prunes map for nil values.
  """
  @spec prune(map) :: map
  def prune(map) do
    map
    |> Enum.map(fn {k, v} -> if is_map(v), do: {k, prune(v)}, else: {k, v} end)
    |> Enum.filter(fn {_, v} -> not is_nil(v) end)
    |> Enum.into(%{})
  end

  @doc """
  Decode a JSON response to a map
  """
  @spec decode_json!(binary() | map(), Keyword.t()) :: map()
  def decode_json!(map, _config) when is_map(map), do: map
  def decode_json!(response, config) do
    json_library = Keyword.get(config, :json_library, default_json_library())
    json_library.decode!(response)
  end

  defp default_json_library do
    Application.get_env(:phoenix, :json_library, Poison)
  end
end
