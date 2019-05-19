defmodule PowAssent.Test.Ecto.UserIdentities.UserIdentity do
  @moduledoc false
  use Ecto.Schema
  use PowAssent.Ecto.UserIdentities.Schema,
    user: PowAssent.Test.Ecto.Users.User

  schema "user_identities" do
    pow_assent_user_identity_fields()

    timestamps(updated_at: false)
  end
end
