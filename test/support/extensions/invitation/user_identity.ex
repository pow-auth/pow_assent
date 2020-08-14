defmodule PowAssent.Test.Invitation.Users.UserIdentity do
  @moduledoc false
  use Ecto.Schema
  use PowAssent.Ecto.Identities.Schema,
    user: PowAssent.Test.Invitation.Users.User

  schema "user_identities" do
    pow_assent_identity_fields()
  end
end
