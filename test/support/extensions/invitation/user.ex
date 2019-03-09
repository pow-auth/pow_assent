defmodule PowAssent.Test.Invitation.Users.User do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema
  use Pow.Extension.Ecto.Schema,
    extensions: [PowInvitation]
  use PowAssent.Ecto.Schema

  schema "users" do
    has_many :user_identities,
      PowAssent.Test.Invitation.UserIdentities.UserIdentity,
      on_delete: :delete_all,
      foreign_key: :user_id

    pow_user_fields()

    timestamps()
  end
end
