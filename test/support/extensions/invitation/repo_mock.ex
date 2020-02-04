defmodule PowAssent.Test.Invitation.RepoMock do
  @moduledoc false

  alias PowAssent.Test.Invitation.{Users.User, UserIdentities.UserIdentity}
  alias PowAssent.Test.RepoMock

  @user %User{id: 1, email: "test@example.com"}

  def get_by(User, [invitation_token: "token"], _opts), do: %{@user | invitation_token: "token"}
  def get_by(UserIdentity, [user_id: 1, provider: "test_provider", uid: "new_identity"], _opts), do: nil

  defdelegate insert(changeset, opts), to: RepoMock

  defdelegate get_by!(struct, clauses, opts), to: RepoMock
end
