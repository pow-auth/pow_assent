defmodule PowAssent.Ecto.UserIdentities.SchemaTest do
  use PowAssent.Test.Ecto.TestCase
  doctest PowAssent.Ecto.UserIdentities.Schema

  alias PowAssent.Test.Ecto.{Repo, UserIdentities.UserIdentity, Users.User}

  test "pow_assent_user_identity_fields/1" do
    user = %UserIdentity{}

    assert Map.has_key?(user, :user)
    assert Map.has_key?(user, :uid)
    assert Map.has_key?(user, :provider)
    refute Map.has_key?(user, :updated_at)
  end

  @valid_params %{user_id: 1, provider: "test_provider", uid: "1"}

  setup do
    {:ok, user: Repo.insert(%User{id: 1, email: "test@example.com"})}
  end

  describe "changeset/3" do
    test "validates required" do
      changeset = UserIdentity.changeset(%UserIdentity{}, %{})

      assert changeset.errors[:uid] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:provider] == {"can't be blank", [validation: :required]}
    end

    test "requires assoc constraint" do
      {:error, changeset} =
        %UserIdentity{}
        |> UserIdentity.changeset(Map.put(@valid_params, :user_id, 2))
        |> Repo.insert()

      assert changeset.errors[:user] == {"does not exist", [constraint: :assoc, constraint_name: "user_identities_user_id_fkey"]}
    end

    test "requires unique uid and provider" do
      {:ok, _user} =
        %UserIdentity{}
        |> Ecto.Changeset.cast(@valid_params, [:provider, :uid])
        |> Repo.insert()

      assert {:error, changeset} =
        %UserIdentity{}
        |> UserIdentity.changeset(@valid_params)
        |> Repo.insert()

      assert changeset.errors[:uid_provider] == {"has already been taken", [constraint: :unique, constraint_name: "user_identities_uid_provider_index"]}
    end
  end
end
