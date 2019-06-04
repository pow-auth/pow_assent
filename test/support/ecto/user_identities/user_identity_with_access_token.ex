defmodule PowAssent.Test.Ecto.UserIdentities.UserIdentityWithAccessToken do
  @moduledoc false
  use Ecto.Schema
  use PowAssent.Ecto.UserIdentities.Schema,
    user: PowAssent.Test.Ecto.Users.User

  schema "user_identities" do
    field :access_token, :string
    field :refresh_token, :string

    pow_assent_user_identity_fields()

    timestamps()
  end

  def changeset(user_identity_or_changeset, attrs) do
    token_params = Map.get(attrs, "token", attrs)

    user_identity_or_changeset
    |> pow_assent_changeset(attrs)
    |> Ecto.Changeset.cast(token_params, [:access_token, :refresh_token])
    |> Ecto.Changeset.validate_required([:access_token])
  end
end
