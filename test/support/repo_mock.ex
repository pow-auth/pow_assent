defmodule PowAssent.Test.RepoMock do
  @moduledoc false

  alias PowAssent.Test.Ecto.{Users.UserIdentity, Users.User}

  def one(query, _opts) do
    case inspect(query) =~ "left_join: u1 in assoc(u0, :user)" and inspect(query) =~ "where: u0.provider == ^\"test_provider\" and u0.uid == ^\"existing_user\"" do
      true  -> %User{id: 1, email: "test@example.com"}
      false -> nil
    end
  end

  def get_by(UserIdentity, [user_id: 1, provider: "test_provider", uid: "existing_user"], _opts), do: %UserIdentity{user_id: 1, provider: "test_provider", uid: "existing_user"}
  def get_by(UserIdentity, [user_id: 1, provider: "test_provider", uid: "new_identity"], _opts), do: nil
  def get_by(UserIdentity, [user_id: 1, provider: "test_provider", uid: "identity_taken"], _opts), do: nil

  @spec insert(%{action: any, valid?: boolean}, any) ::
          {:error, %{action: :insert, valid?: false}} | {:ok, %{id: 1}}
  def insert(%{changes: %{provider: "test_provider", uid: "identity_taken"}} = changeset, _opts) do
    changeset = Ecto.Changeset.add_error(changeset, :uid, "has already been taken", constraint: :unique, constraint_name: "user_identities_uid_provider_index")

    {:error, %{changeset | action: :insert}}
  end
  def insert(%{changes: %{email: "taken@example.com"}} = changeset, _opts) do
    changeset = Ecto.Changeset.add_error(changeset, :email, "has already been taken", constraint: :unique, constraint_name: "users_email_index")

    {:error, %{changeset | action: :insert}}
  end
  def insert(%{valid?: true, changes: %{identities: [%{changes: %{provider: "test_provider", uid: "identity_taken"}} = identity_changeset]}} = changeset, _opts) do
    identity_changeset = Ecto.Changeset.add_error(identity_changeset, :uid, "has already been taken", constraint: :unique, constraint_name: "user_identities_uid_provider_index")
    identity_changeset = %{identity_changeset | action: :insert}
    changeset          = Ecto.Changeset.put_change(changeset, :identities, [identity_changeset])

    {:error, %{changeset | action: :insert}}
  end
  def insert(%{valid?: true, data: %mod{}} = changeset, _opts) do
    struct = %{Ecto.Changeset.apply_changes(changeset) | id: :inserted}

    # We store the struct in the process because the struct is force reloaded with `get_by!/2`
    Process.put({mod, :inserted}, struct)

    {:ok, struct}
  end
  def insert(%{valid?: false} = changeset, _opts), do: {:error, %{changeset | action: :insert}}

  def update(%{valid?: true, data: %mod{}} = changeset, _opts) do
    struct = %{Ecto.Changeset.apply_changes(changeset) | id: :updated}

    # We store the user in the process because the user is force reloaded with `get_by!/2`
    Process.put({mod, :updated}, struct)

    {:ok, struct}
  end

  def get_by!(struct, [id: id], _opts), do: Process.get({struct, id})

  def preload(%User{id: :multiple_identities} = user, :identities, force: true), do: %{user | identities: [%UserIdentity{id: 1, provider: "test_provider"}, %UserIdentity{id: 2, provider: "other_provider"}]}
  def preload(user, :identities, force: true), do: %{user | identities: [%UserIdentity{id: 1, provider: "test_provider"}]}

  def delete_all(query, _opts) do
    case inspect(query) =~ "where: u0.user_id == ^1, where: u0.id in ^[1]" do
      true  -> {1, nil}
      false -> {0, nil}
    end
  end

  def all(query, _otps) do
    case inspect(query) =~ "where: u0.user_id == ^1" do
      true -> [%UserIdentity{user_id: 1, provider: "test_provider", uid: "existing_user"}]
      false -> []
    end
  end
end
