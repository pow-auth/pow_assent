defmodule PowAssent.Test.Ecto.UserIdentities.EmailConfirmUserIdentity do
  @moduledoc false
  use Ecto.Schema
  use PowAssent.Ecto.UserIdentities.Schema,
    user: PowAssent.Test.Ecto.Users.EmailConfirmUser

  schema "user_identities" do
    pow_user_identity_schema()
  end
end
