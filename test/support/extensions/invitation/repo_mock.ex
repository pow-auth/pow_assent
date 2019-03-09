defmodule PowAssent.Test.Invitation.RepoMock do
  @moduledoc false

  alias PowAssent.Test.Invitation.Users.User

  @user %User{id: 1, email: "test@example.com"}

  def get_by(User, [invitation_token: "token"]), do: %{@user | invitation_token: "token"}
end
