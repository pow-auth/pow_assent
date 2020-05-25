defmodule PowAssent.Test.Ecto.Users.UserIdentity do
  @moduledoc false
  use Ecto.Schema
  use PowAssent.Ecto.Identities.Schema,
    user: PowAssent.Test.Ecto.Users.User

  schema "user_identities" do
    pow_assent_identity_fields()

    timestamps()
  end
end
