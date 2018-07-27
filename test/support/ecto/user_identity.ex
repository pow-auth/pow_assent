defmodule PowAssent.Test.Ecto.UserIdentities.UserIdentity do
  @moduledoc false
  use Ecto.Schema
  use PowAssent.Ecto.UserIdentities.Schema,
    user: PowAssent.Test.Ecto.Users.User

  schema "user_identities" do
    pow_user_identity_schema()

    timestamps(updated_at: false)
  end
end
