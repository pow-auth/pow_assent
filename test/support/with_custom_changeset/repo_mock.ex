defmodule PowAssent.Test.WithCustomChangeset.RepoMock do
  @moduledoc false

  alias PowAssent.Test.RepoMock
  alias PowAssent.Test.WithCustomChangeset.{UserIdentities.UserIdentity, Users.User}

  def one(query, _opts) do
    case inspect(query) =~ "left_join: u1 in assoc(u0, :user)" and inspect(query) =~ "where: u0.provider == ^\"test_provider\" and u0.uid == ^\"existing_user\"" do
      true  -> %User{id: 1, email: "test@example.com"}
      false -> nil
    end
  end

  def get_by(UserIdentity, [user_id: 1, provider: "test_provider", uid: "new_identity"], _opts), do: nil
  def get_by(UserIdentity, [user_id: 1, provider: "test_provider", uid: "existing_user"], _opts), do: %UserIdentity{user_id: 1, provider: "test_provider", uid: "existing_user"}

  defdelegate insert(changeset, opts), to: RepoMock

  defdelegate update(changeset, opts), to: RepoMock

  defdelegate get_by!(struct, clauses, opts), to: RepoMock
end
