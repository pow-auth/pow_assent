defmodule PowAssent.Ecto.UserIdentities.Schema.Module do
  @moduledoc """
  Generates schema module content.

  ## Configuration options

    * `:table` the ecto table name
  """
  alias Pow.Config

  @template """
    defmodule <%= inspect schema.module %> do
      use Ecto.Schema
      use PowAssent.Ecto.UserIdentities.Schema

    <%= if schema.binary_id do %>
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id<% end %>
      schema <%= inspect schema.table %> do
        pow_assent_user_identity_fields()

        timestamps(updated_at: false)
      end
    end
    """

  @spec gen(atom(), Config.t()) :: binary()
  def gen(context_base, config \\ []) do
    context_base
    |> parse_options(config)
    |> schema_module()
  end

  defp parse_options(base, config) do
    module        = Module.concat([base, "UserIdentities", "UserIdentity"])
    table         = Config.get(config, :table, "user_identities")
    binary_id     = config[:binary_id]

    %{
      module: module,
      table: table,
      binary_id: binary_id,
    }
  end

  defp schema_module(schema) do
    EEx.eval_string(unquote(@template), schema: schema)
  end
end
