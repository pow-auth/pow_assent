defmodule PowAssent.Ecto.UserIdentities.Schema.Fields do
  @moduledoc """
  Handles the Ecto schema fields for user.
  """
  alias Pow.Config

  @spec attrs(Config.t()) :: [tuple()]
  def attrs(config) do
    users_table = Config.get(config, :users_table, "users")

    [{:user_id, {:references, users_table}},
     {:provider, :string, null: false},
     {:uid, :string, null: false}]
  end

  @spec indexes(Config.t()) :: [tuple()]
  def indexes(_config) do
    [{[:uid, :provider], true}]
  end
end
