defmodule PowAssent.Ecto.UserIdentities.ContextTest do
  use PowAssent.Test.Ecto.TestCase
  doctest PowAssent.Ecto.UserIdentities.Context

  alias Ecto.Changeset
  alias PowAssent.Ecto.UserIdentities.Context
  alias PowAssent.Test.Ecto.{Repo, Users.User}

  @config [repo: Repo, user: User]

  describe "get_user_by_provider_uid/2" do
    setup do
      user =
        %User{}
        |> Changeset.change(email: "test@example.com", user_identities: [%{provider: "test_provider", uid: "1"}])
        |> Repo.insert!()

      {:ok, %{user: user}}
    end

    test "retrieves", %{user: user} do
      get_user = Context.get_user_by_provider_uid(@config, "test_provider", "1")

      assert get_user.id == user.id

      refute Context.get_user_by_provider_uid(@config, "test_provider", "2")

      {:ok, _user} = Repo.delete(user)
      refute Context.get_user_by_provider_uid(@config, "test_provider", "1")
    end
  end

  describe "create/5" do
    setup do
      user =
        %User{}
        |> Changeset.change(email: "test@example.com")
        |> Repo.insert!()

      {:ok, %{user: user}}
    end

    test "with valid params", %{user: user} do
      assert {:ok, user_identity} = Context.create(@config, user, "test_provider", "1")
      assert user_identity.provider == "test_provider"
      assert user_identity.uid == "1"
    end

    test "when other user has provider uid", %{user: user} do
      _second_user =
        %User{}
        |> Changeset.change(email: "test-2@example.com", user_identities: [%{provider: "test_provider", uid: "1"}])
        |> Repo.insert!()

      assert {:error, {:bound_to_different_user, _changeset}} = Context.create(@config, user, "test_provider", "1")
    end
  end

  describe "create_user/5" do
    @valid_params %{name: "John Doe", email: "test@example.com"}

    test "with valid params" do
      assert {:ok, user} = Context.create_user(@config, "test_provider", "1", @valid_params)
      assert user.name == "John Doe"
      assert user.email == "test@example.com"
      assert [user_identity] = user.user_identities
      assert user_identity.provider == "test_provider"
      assert user_identity.uid == "1"
    end

    test "when other user has provider uid" do
      _second_user =
        %User{}
        |> Changeset.change(email: "test-2@example.com", user_identities: [%{provider: "test_provider", uid: "1"}])
        |> Repo.insert!()

      assert {:error, {:bound_to_different_user, _changeset}} =  Context.create_user(@config, "test_provider", "1", @valid_params)
    end

    test "when user id field is missing" do
      assert {:error, {:missing_user_id_field, _changeset}} =  Context.create_user(@config, "test_provider", "1", Map.delete(@valid_params, :email))
    end
  end

  describe "delete/3" do
    setup do
      user =
        %User{}
        |> Changeset.change(email: "test@example.com", user_identities: [%{provider: "test_provider", uid: "1"}, %{provider: "test_provider", uid: "2"}])
        |> Repo.insert!()

      {:ok, user: user}
    end

    test "requires password hash or other identity", %{user: user} do
      assert {:error, {:no_password, _changeset}} = Context.delete(@config, user, "test_provider")

      Repo.insert!(Ecto.build_assoc(user, :user_identities, %{provider: "another_provider", uid: "1"}))
      assert {:ok, {2, nil}} = Context.delete(@config, user, "test_provider")

      user = %{user | password_hash: "password"}
      assert {:ok, {1, nil}} = Context.delete(@config, user, "another_provider")
    end
  end

  test "all/2 retrieves" do
    user =
      %User{}
      |> Changeset.change(email: "test@example.com", user_identities: [%{provider: "test_provider", uid: "1"}, %{provider: "other_provider", uid: "1"}])
      |> Repo.insert!()

    second_user =
      %User{}
      |> Changeset.change(email: "test-2@example.com", user_identities: [%{provider: "test_provider", uid: "2"}])
      |> Repo.insert!()

    assert [%{provider: "test_provider", uid: "2"}] = Context.all(@config, second_user)
    assert [%{provider: "test_provider", uid: "1"}, %{provider: "other_provider", uid: "1"}] = Context.all(@config, user)
  end
end
