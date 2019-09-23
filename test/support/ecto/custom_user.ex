defmodule PowAssent.Test.Ecto.Users.CustomUser do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema, user_id_field: :user_name
  use PowAssent.Ecto.Schema

  schema "users" do
    field :user_name, :string
    field :email, :string
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
    |> cast_email( attrs, user_id_attrs )
    |> put_username_from_uid( attrs )
    |> pow_assent_user_identity_changeset(user_identity, attrs, user_id_attrs)
    |> validate_name(attrs)
    |> validate_email()
  end

  defp cast_email( user_or_changeset, attrs, user_id_attrs ) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:email])
    |> Ecto.Changeset.cast(user_id_attrs || %{}, [:email]) # Make sure that we cast user input last to override the one fetched from Github
  end

  defp validate_email( user_or_changeset ) do
    user_or_changeset
    |> Ecto.Changeset.validate_required([:email])
    |> Ecto.Changeset.unique_constraint(:email)
  end

  defp validate_name(user_or_changeset, attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:name])
    |> Ecto.Changeset.validate_required([:name])
  end

  defp put_username_from_uid(changeset, %{uid: user_name}), do: Ecto.Changeset.put_change(changeset, :user_name, user_name)
  defp put_username_from_uid(changeset, _attrs), do: changeset
end
