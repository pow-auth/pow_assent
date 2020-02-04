defmodule PowAssent.Test.EmailConfirmation.RepoMock do
  @moduledoc false

  alias PowAssent.Test.EmailConfirmation.{UserIdentities.UserIdentity, Users.User}
  alias PowAssent.Test.RepoMock

  def one(query, _opts) do
    case inspect(query) =~ "left_join: u1 in assoc(u0, :user)" and inspect(query) =~ "where: u0.provider == ^\"test_provider\" and u0.uid == ^\"existing_user-missing_email_confirmation\"" do
      true  -> %User{id: 1, email: "test@example.com", email_confirmation_token: "token", email_confirmed_at: nil}
      false -> nil
    end
  end

  def get_by(UserIdentity, [user_id: 1, provider: "test_provider", uid: "existing_user-missing_email_confirmation"], _opts), do: %UserIdentity{user_id: 1, provider: "test_provider", uid: "existing_user-missing_email_confirmation"}

  defdelegate insert(changeset, opts), to: RepoMock

  defdelegate update(changeset, opts), to: RepoMock

  defdelegate get_by!(struct, clauses, opts), to: RepoMock
end
