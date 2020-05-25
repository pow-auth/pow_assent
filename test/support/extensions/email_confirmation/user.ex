defmodule PowAssent.Test.EmailConfirmation.Users.User do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema
  use Pow.Extension.Ecto.Schema,
    extensions: [PowEmailConfirmation]
  use PowAssent.Ecto.Schema

  schema "users" do
    field :name, :string

    pow_user_fields()

    timestamps()
  end

  def identity_changeset(user_or_changeset, identity, attrs, user_id_attrs) do
    user_or_changeset
    |> validate_name(attrs)
    |> pow_assent_identity_changeset(identity, attrs, user_id_attrs)
  end

  defp validate_name(changeset, attrs) do
    changeset
    |> Ecto.Changeset.cast(attrs, [:name])
    |> Ecto.Changeset.validate_required([:name])
  end
end
