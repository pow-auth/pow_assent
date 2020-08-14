defmodule PowAssent.Ecto.Identities.Schema.Module do
  @moduledoc """
  Generates schema module content.

  ## Configuration options

    * `:binary_id` - if the schema module should use binary id, default nil.
  """
  alias PowAssent.Config

  @template """
  defmodule <%= inspect schema.module %> do
    use Ecto.Schema
    use PowAssent.Ecto.Identities.Schema, user: <%= inspect(schema.user_module) %>
  <%= if schema.binary_id do %>
    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id<% end %>
    schema <%= inspect schema.table %> do
      pow_assent_identity_fields()

      timestamps()
    end
  end
  """

  @doc """
  Generates schema module file content.
  """
  @spec gen(map()) :: binary()
  def gen(schema) do
    EEx.eval_string(unquote(@template), schema: schema)
  end

  @doc """
  Generates a schema module map.
  """
  @spec new(atom(), binary(), binary(), Config.t()) :: map()
  def new(context_base, schema_name, schema_plural, config \\ []) do
    module      = Module.concat([context_base, schema_name])
    binary_id   = config[:binary_id]
    user_module = Module.concat([context_base, "Users.User"])

    %{
      schema_name: schema_name,
      module: module,
      table: schema_plural,
      binary_id: binary_id,
      user_module: user_module
    }
  end
end
