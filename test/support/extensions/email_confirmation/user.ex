defmodule PowAssent.Test.EmailConfirmation.Users.User do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema
  use Pow.Extension.Ecto.Schema,
    extensions: [PowEmailConfirmation]
  use PowAssent.Ecto.Schema

  schema "users" do
    pow_user_fields()

    timestamps()
  end
end
