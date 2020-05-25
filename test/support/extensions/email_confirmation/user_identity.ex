defmodule PowAssent.Test.EmailConfirmation.Users.UserIdentity do
  @moduledoc false
  use Ecto.Schema
  use PowAssent.Ecto.Identities.Schema,
    user: PowAssent.Test.EmailConfirmation.Users.User

  schema "user_identities" do
    pow_assent_identity_fields()
  end
end
