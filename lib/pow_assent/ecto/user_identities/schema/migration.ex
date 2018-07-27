defmodule PowAssent.Ecto.UserIdentities.Schema.Migration do
  @moduledoc """
  Generates schema migration content.
  """
  alias PowAssent.Ecto.UserIdentities.Schema.Fields
  alias Pow.Ecto.Schema.Migration

  @spec gen(atom(), Config.t()) :: binary()
  def gen(context_base, config \\ []) do
    table   = "user_identities"
    attrs   = Fields.attrs(config)
    indexes = Fields.indexes(config)
    config  = Keyword.merge(config, [
      table: table,
      attrs: attrs,
      indexes: indexes])

    context_base
    |> Migration.gen(config)
    |> String.replace("timestamps()", "timestamps(updated_at: false)")
  end
end
