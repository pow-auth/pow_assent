defmodule PowAssent.Test.Invitation.UserIdentities.UserIdentity do
  @moduledoc false
  use Ecto.Schema
  use PowAssent.Ecto.UserIdentities.Schema,
    user: PowAssent.Test.Invitation.Users.User

  schema "user_identities" do
    pow_assent_user_identity_fields()
  end
end
