defmodule PowAssent.Test.Ecto.Users.UserConfirmEmail do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema
  use Pow.Extension.Ecto.Schema,
    extensions: [PowEmailConfirmation]
  use PowAssent.Ecto.Schema

  schema "users" do
    has_many :user_identities,
      PowAssent.Test.Ecto.UserIdentities.UserIdentityConfirmEmail,
      on_delete: :delete_all,
      foreign_key: :user_id

    pow_user_fields()

    timestamps()
  end

  def user_identity_changeset(user_or_changeset, user_identity, attrs, user_id_attrs) do
    user_or_changeset
    |> pow_assent_user_identity_changeset(user_identity, attrs, user_id_attrs)
    |> pow_extension_changeset(attrs)
  end
end
