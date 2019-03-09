defmodule PowAssent.Ecto.UserIdentities.Schema.Fields do
  @moduledoc """
  Handles the Ecto schema fields for user.
  """
  alias PowAssent.Config

  @doc """
  List of attributes for the ecto schema.
  """
  @spec attrs(Config.t()) :: [tuple()]
  def attrs(_config) do
    [
      {:provider, :string, null: false},
      {:uid, :string, null: false}
    ]
  end

  @doc """
  List of associations for the ecto schema.
  """
  @spec assocs(Config.t()) :: [tuple()]
  def assocs(_config) do
    [{:belongs_to, :user, :users}]
  end

  @doc """
  List of indexes for the ecto schema.
  """
  @spec indexes(Config.t()) :: [tuple()]
  def indexes(_config) do
    [{[:uid, :provider], true}]
  end
end
