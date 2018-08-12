defmodule PowAssent.Strategy do
  @moduledoc false
  alias Plug.Conn

  @callback authorize_url(Keyword.t(), Conn.t()) ::
              {:ok, %{:conn => Conn.t(), :url => binary(), optional(atom()) => any()}}
              | {:error, %{conn: Conn.t(), error: any()}}
  @callback callback(Keyword.t(), Conn.t(), map()) ::
              {:ok, %{:conn => Conn.t(), :user => map(), optional(atom()) => any()}}
              | {:error, %{conn: Conn.t(), error: any()}}

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      alias Plug.Conn
      alias unquote(__MODULE__), as: Helpers
    end
  end

  @spec prune(map) :: map
  def prune(map) do
    map
    |> Enum.map(fn {k, v} -> if is_map(v), do: {k, prune(v)}, else: {k, v} end)
    |> Enum.filter(fn {_, v} -> not is_nil(v) end)
    |> Enum.into(%{})
  end
end
