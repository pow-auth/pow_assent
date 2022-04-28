defmodule PowAssent.Ecto.UserIdentities.Schema.Migration do
  @moduledoc """
  Generates schema migration content.
  """
  alias Pow.Ecto.Schema.Migration
  alias PowAssent.{Config, Ecto.UserIdentities.Schema.Fields}

  @doc """
  Generates migration schema map.
  """
  @spec new(atom(), binary(), Config.t()) :: map()
  def new(context_base, schema_plural, config \\ []) do
    attrs   = attrs(config)
    indexes = Fields.indexes(config)
    config  = Keyword.merge(config, attrs: attrs, indexes: indexes)

    Migration.new(context_base, schema_plural, config)
  end

  defp attrs(config) do
    config
    |> Fields.attrs()
    |> Kernel.++(attrs_from_assocs(config))
  end

  defp attrs_from_assocs(config) do
    config
    |> Fields.assocs()
    |> Enum.map(&attr_from_assoc(&1, config))
    |> Enum.reject(&is_nil/1)
  end

  defp attr_from_assoc({:belongs_to, name, :users, field_options, migration_options}, config) do
    users_table = Config.get(config, :users_table, "users")

    {String.to_atom("#{name}_id"), {:references, users_table}, field_options, migration_options}
  end
  defp attr_from_assoc(_assoc, _opts), do: nil

  @doc false
  defdelegate gen(schema), to: Migration
end
