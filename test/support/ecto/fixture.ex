# defmodule PowAssent.Test.Ecto.Fixture do
#   alias PowAssent.Test.Ecto.Repo
#   alias PowAssent.Test.Ecto.Users.User
#   # alias PowAssent.UserIdentities.UserIdentity

#   def user(attrs \\ %{}) do
#     %User{}
#     |> Map.merge(%{email: "user@example.com"})
#     |> Map.merge(attrs)
#     |> Repo.insert!()
#   end
#   # def user_identity(user, attrs) do
#   #   {:ok, identity} = %UserIdentity{user: user}
#   #   |> Map.merge(%{provider: "test_provider", uid: "1"})
#   #   |> Map.merge(attrs)
#   #   |> Repo.insert

#   #   identity
#   # end
# end
