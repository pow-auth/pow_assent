defmodule Mix.PowAssent do
  @moduledoc """
  Utilities module for mix tasks.
  """

  @doc false
  @spec validate_schema_args!([binary()], binary()) :: map() | no_return
  def validate_schema_args!([schema, plural | _rest] = args, task) do
    cond do
      not schema_valid?(schema) ->
        raise_invalid_schema_args_error!("Expected the schema argument, #{inspect schema}, to be a valid module name", task)
      not plural_valid?(plural) ->
        raise_invalid_schema_args_error!("Expected the plural argument, #{inspect plural}, to be all lowercase using snake_case convention", task)
      true ->
        schema_options_from_args(args)
    end
  end
  def validate_schema_args!([_schema | _rest], task) do
    raise_invalid_schema_args_error!("Invalid arguments", task)
  end
  def validate_schema_args!([], _task), do: schema_options_from_args()

  defp schema_valid?(schema), do: schema =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/

  defp plural_valid?(plural), do: plural =~ ~r/^[a-z\_]*$/

  @spec raise_invalid_schema_args_error!(binary(), binary()) :: no_return()
  defp raise_invalid_schema_args_error!(msg, task) do
    Mix.raise("""
    #{msg}

    mix #{task} accepts both a module name and the plural of the resource:
        mix #{task} Users.UserIdentity user_identities
    """)
  end

  defp schema_options_from_args(_opts \\ [])
  defp schema_options_from_args([schema, plural | _rest]), do: %{schema_name: schema, schema_plural: plural}
  defp schema_options_from_args(_any), do: %{schema_name: "Users.UserIdentity", schema_plural: "user_identities"}
end
