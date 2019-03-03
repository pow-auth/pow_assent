defmodule PowAssent.Test.Ecto.Users.User do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema
  use PowAssent.Ecto.Schema

  schema "users" do
    field :name, :string

    pow_user_fields()

    timestamps()
  end

  def changeset(user_or_changeset, attrs) do
    user_or_changeset
    |> validate_name(attrs)
    |> pow_changeset(attrs)
  end

  def user_identity_changeset(user_or_changeset, user_identity, attrs, user_id_attrs) do
    user_or_changeset
    |> validate_name(attrs)
    |> pow_assent_user_identity_changeset(user_identity, attrs, user_id_attrs)
  end

  defp validate_name(changeset, attrs) do
    changeset
    |> Ecto.Changeset.cast(attrs, [:name])
    |> Ecto.Changeset.validate_required([:name])
  end
end
