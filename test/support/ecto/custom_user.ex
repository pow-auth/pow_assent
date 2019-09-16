defmodule PowAssent.Test.Ecto.Users.CustomUser do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema, user_id_field: :user_name
  use PowAssent.Ecto.Schema

  schema "users" do
    field :user_name, :string
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
    |> put_username(attrs)
    |> validate_email(attrs, user_id_attrs)
    |> validate_name(attrs)
    |> pow_assent_user_identity_changeset(user_identity, attrs, user_id_attrs)
    |> Ecto.Changeset.unique_constraint(:user_name, on: User.Repo)
  end

  defp validate_email(user_or_changeset, attrs, user_id_attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:email])
    |> maybe_cast_user_id_attrs_email( user_id_attrs )
    |> Ecto.Changeset.validate_required([:email])
    |> Ecto.Changeset.unique_constraint([:email])
  end
  defp maybe_cast_user_id_attrs_email( user_or_changeset, nil ), do: user_or_changeset
  defp maybe_cast_user_id_attrs_email( user_or_changeset, user_id_attrs ), do: Ecto.Changeset.cast(user_or_changeset, user_id_attrs, [:email])

  defp put_username(changeset, %{"uid" => user_name}), do: Ecto.Changeset.put_change(changeset, :user_name, user_name)
  defp put_username(changeset, _attrs), do: changeset

  defp validate_name(user_or_changeset, attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:name])
    |> Ecto.Changeset.validate_required([:name])
  end
end
