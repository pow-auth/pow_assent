defmodule PowAssent.Test.Ecto.Users.UserWithoutUserIdentities do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema

  schema "users" do
    pow_user_fields()
    timestamps()
  end
end

defmodule PowAssent.Test.Ecto.Users.UserWithAccessTokenUserIdentities do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema
  use PowAssent.Ecto.Schema

  schema "users" do
    has_many :identities, PowAssent.Test.WithAccessToken.UserIdentities.UserIdentity, foreign_key: :user_id, on_delete: :delete_all

    pow_user_fields()
    timestamps()
  end
end

defmodule PowAssent.Ecto.UserIdentities.ContextTest do
  use PowAssent.Test.Ecto.TestCase
  doctest PowAssent.Ecto.UserIdentities.Context

  alias Ecto.Changeset
  alias PowAssent.Ecto.UserIdentities.Context
  alias PowAssent.Test.Ecto.{Repo, Users.User, Users.UserWithoutUserIdentities, Users.UserWithAccessTokenUserIdentities, Users.User}

  @config [repo: Repo, user: User]
  @identity_params %{provider: "test_provider", uid: "1"}

  describe "get_user_by_provider_uid/2" do
    setup do
      user =
        %User{}
        |> Changeset.change(email: "test@example.com", identities: [@identity_params])
        |> Repo.insert!()

      user = Repo.get!(user.__struct__, user.id)

      {:ok, user: user}
    end

    test "retrieves", %{user: user} do
      assert Context.get_user_by_provider_uid("test_provider", "1", @config) == user
      assert Context.get_user_by_provider_uid("test_provider", 1, @config) == user

      refute Context.get_user_by_provider_uid("test_provider", "2", @config)

      Repo.delete!(user)
      refute Context.get_user_by_provider_uid("test_provider", "1", @config)
    end

    test "requires user has :identities assoc" do
      assert_raise PowAssent.Config.ConfigError, "The `:user` configuration option doesn't have a `:identities` association.", fn ->
        Context.get_user_by_provider_uid("test_provider", "2", repo: Repo, user: UserWithoutUserIdentities)
      end
    end
  end

  @config_with_access_token [repo: Repo, user: UserWithAccessTokenUserIdentities]
  @identity_params_with_access_token Map.put(@identity_params, :token, %{access_token: "access_token"})

  describe "upsert/3" do
    setup do
      user =
        %UserWithAccessTokenUserIdentities{}
        |> Changeset.change(email: "test@example.com")
        |> Repo.insert!()

      {:ok, user: user}
    end

    test "inserts with valid params", %{user: user} do
      assert {:ok, identity} = Context.upsert(user, @identity_params_with_access_token, @config_with_access_token)
      assert identity.provider == "test_provider"
      assert identity.uid == "1"
    end

    test "inserts with integer uid param", %{user: user} do
      params = Map.put(@identity_params_with_access_token, :uid, 1)

      assert {:ok, identity} = Context.upsert(user, params, @config_with_access_token)
      assert identity.uid == "1"
    end

    test "updates with valid params", %{user: user} do
      assert {:ok, prev_identity} = Context.upsert(user, @identity_params_with_access_token, @config_with_access_token)
      assert prev_identity.access_token
      refute prev_identity.refresh_token

      params = Map.put(@identity_params_with_access_token, :token, %{access_token: "changed_access_token", refresh_token: "refresh_token"})

      assert {:ok, identity} = Context.upsert(user, params, @config_with_access_token)
      assert prev_identity.id == identity.id
      assert identity.provider == "test_provider"
      assert identity.uid == "1"
      assert identity.access_token == "changed_access_token"
      assert identity.refresh_token == "refresh_token"

      params = Map.put(@identity_params_with_access_token, :uid, 1)

      assert {:ok, identity} = Context.upsert(user, params, @config_with_access_token)
      assert identity.uid == "1"
      assert identity.access_token == "access_token"
    end

    test "when other user has provider uid", %{user: user} do
      _second_user =
        %UserWithAccessTokenUserIdentities{}
        |> Changeset.change(email: "test-2@example.com")
        |> Changeset.cast(%{identities: [@identity_params_with_access_token]}, [])
        |> Changeset.cast_assoc(:identities)
        |> Repo.insert!()

      assert {:error, {:bound_to_different_user, _changeset}} = Context.upsert(user, @identity_params_with_access_token, @config_with_access_token)
    end
  end

  describe "create_user/4" do
    @user_params %{name: "John Doe", email: "test@example.com"}

    test "with valid params" do
      assert {:ok, user} = Context.create_user(@identity_params, @user_params, nil, @config)
      user = Repo.preload(user, :identities, force: true)

      assert user.name == "John Doe"
      assert user.email == "test@example.com"
      assert [identity] = user.identities
      assert identity.provider == "test_provider"
      assert identity.uid == "1"
    end

    test "with valid params with access token" do
      assert {:ok, user} = Context.create_user(@identity_params_with_access_token, @user_params, nil, @config_with_access_token)
      user = Repo.preload(user, :identities, force: true)

      assert [identity] = user.identities
      assert identity.provider == "test_provider"
      assert identity.uid == "1"
      assert identity.access_token == "access_token"
    end

    test "with integer uid param" do
      params = Map.put(@identity_params, "uid", 1)

      assert {:ok, user} = Context.create_user(params, @user_params, nil, @config)
      user = Repo.preload(user, :identities, force: true)

      assert [identity] = user.identities
      assert identity.uid == "1"
    end

    test "when other user has provider uid" do
      _second_user =
        %User{}
        |> Changeset.change(email: "test-2@example.com", identities: [@identity_params])
        |> Repo.insert!()

      assert {:error, {:bound_to_different_user, _changeset}} = Context.create_user(@identity_params, @user_params, nil, @config)
    end

    test "when user id field is missing" do
      assert {:error, {:invalid_user_id_field, _changeset}} =  Context.create_user(@identity_params, Map.delete(@user_params, :email), nil, @config)
    end
  end

  describe "delete/3" do
    setup do
      user =
        %User{}
        |> Changeset.change(email: "test@example.com", identities: [@identity_params, %{provider: "test_provider", uid: "2"}])
        |> Repo.insert!()

      {:ok, user: user}
    end

    test "requires password hash or other identity", %{user: user} do
      assert {:error, {:no_password, _changeset}} = Context.delete(user, "test_provider", @config)

      Repo.insert!(Ecto.build_assoc(user, :identities, %{provider: "another_provider", uid: "1"}))
      assert {:ok, {2, nil}} = Context.delete(user, "test_provider", @config)

      user = %{user | password_hash: "password"}
      assert {:ok, {1, nil}} = Context.delete(user, "another_provider", @config)
    end
  end

  test "all/2 retrieves" do
    user =
      %User{}
      |> Changeset.change(email: "test@example.com", identities: [%{provider: "test_provider", uid: "1"}, %{provider: "other_provider", uid: "1"}])
      |> Repo.insert!()

    second_user =
      %User{}
      |> Changeset.change(email: "test-2@example.com", identities: [%{provider: "test_provider", uid: "2"}])
      |> Repo.insert!()

    assert [%{provider: "test_provider", uid: "2"}] = Context.all(second_user, @config)
    assert [%{provider: "test_provider", uid: "1"}, %{provider: "other_provider", uid: "1"}] = Context.all(user, @config)
  end
end
