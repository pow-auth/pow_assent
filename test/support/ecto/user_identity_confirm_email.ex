defmodule PowAssent.Test.Ecto.UserIdentities.UserIdentityConfirmEmail do
  @moduledoc false
  use Ecto.Schema
  use PowAssent.Ecto.UserIdentities.Schema,
    user: PowAssent.Test.Ecto.Users.UserConfirmEmail

  schema "user_identities" do
    pow_assent_user_identity_fields()
  end
end
