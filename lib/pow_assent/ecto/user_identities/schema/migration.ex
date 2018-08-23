defmodule PowAssent.Ecto.UserIdentities.Schema.Migration do
  @moduledoc """
  Generates schema migration content.
  """
  alias Pow.Ecto.Schema.Migration
  alias PowAssent.Ecto.UserIdentities.Schema.Fields

  @doc """
  Generates migration schema map.
  """
  @spec new(atom(), binary(), Config.t()) :: map()
  def new(context_base, schema_plural, config \\ []) do
    attrs   = Fields.attrs(config)
    indexes = Fields.indexes(config)
    config  = Keyword.merge(config, attrs: attrs, indexes: indexes)

    Migration.new(context_base, schema_plural, config)
  end

  @doc """
  Generates migration file content.
  """
  @spec gen(map()) :: binary()
  def gen(schema) do
    schema
    |> Migration.gen()
    |> String.replace("timestamps()", "timestamps(updated_at: false)")
  end
end
