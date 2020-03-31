defmodule PowAssent.Test.WithCustomChangeset.UserIdentities.UserIdentity do
  @moduledoc false
  use Ecto.Schema
  use PowAssent.Ecto.UserIdentities.Schema,
    user: PowAssent.Test.WithCustomChangeset.Users.User

  schema "user_identities" do
    field :access_token, :string
    field :refresh_token, :string

    field :name, :string

    pow_assent_user_identity_fields()

    timestamps()
  end

  def changeset(user_identity_or_changeset, attrs) do
    token_params = Map.get(attrs, "token") || Map.get(attrs, :token) || attrs
    userinfo_params = Map.get(attrs, "userinfo", %{})

    user_identity_or_changeset
    |> pow_assent_changeset(attrs)
    |> Ecto.Changeset.cast(token_params, [:access_token, :refresh_token])
    |> Ecto.Changeset.cast(userinfo_params, [:name])
    |> Ecto.Changeset.validate_required([:access_token])
  end
end
