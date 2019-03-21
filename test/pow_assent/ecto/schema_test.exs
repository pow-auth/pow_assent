defmodule PowAssent.NoContextUser do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema
  use PowAssent.Ecto.Schema

  schema "users" do
    pow_user_fields()

    timestamps()
  end
end

defmodule PowAssent.Ecto.SchemaTest do
  use PowAssent.Test.Ecto.TestCase
  doctest PowAssent.Ecto.Schema

  alias PowAssent.Test.Ecto.{Repo, Users.User}
  alias PowAssent.Test.EmailConfirmation.Users.User, as: UserConfirmEmail
  alias PowAssent.Test.Invitation.Users.User, as: InvitationUser

  test "user_schema/1" do
    user = %User{}

    assert Map.has_key?(user, :user_identities)
    assert %{on_delete: :delete_all} = User.__schema__(:association, :user_identities)
  end

  @user_identity %{
    provider: "test_provider",
    uid: "1"
  }

  describe "user_identity_changeset/4" do
    test "validates required" do
      changeset = User.user_identity_changeset(%User{}, %{}, %{}, nil)

      assert [user_identity] = changeset.changes.user_identities
      assert user_identity.errors[:uid] == {"can't be blank", [validation: :required]}
      assert user_identity.errors[:provider] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:name] == {"can't be blank", [validation: :required]}

      changeset = User.user_identity_changeset(%User{}, @user_identity, %{email: "test@example.com", name: "John Doe"}, nil)
      assert changeset.valid?
      assert changeset.changes[:name] == "John Doe"
    end

    test "validates unique" do
      {:ok, _user} =
        %User{email: "test@example.com"}
        |> Ecto.Changeset.cast(%{"user_identities" => [@user_identity]}, [])
        |> Ecto.Changeset.cast_assoc(:user_identities)
        |> Repo.insert()

      assert {:error, changeset} =
        %User{email: "john.doe@example.com", name: "John Doe"}
        |> User.user_identity_changeset(@user_identity, %{}, nil)
        |> Repo.insert()

      assert [user_identity] = changeset.changes.user_identities
      assert user_identity.errors[:uid_provider] == {"has already been taken", [constraint: :unique, constraint_name: "user_identities_uid_provider_index"]}
    end

    test "sets :email_confirmed_at when provided as attrs" do
      changeset = UserConfirmEmail.user_identity_changeset(%UserConfirmEmail{}, @user_identity, %{}, %{email: "test@example.com"})
      refute changeset.changes[:email_confirmed_at]

      changeset = UserConfirmEmail.user_identity_changeset(%UserConfirmEmail{}, @user_identity, %{email: "test@example.com"}, nil)
      assert changeset.changes[:email_confirmed_at]

      changeset = User.user_identity_changeset(%User{}, @user_identity, %{email: "test@example.com"}, nil)
      refute changeset.changes[:email_confirmed_at]
    end

    test "sets :invitation_accepted_at when is invited user" do
      changeset = InvitationUser.user_identity_changeset(%InvitationUser{}, @user_identity, %{}, %{email: "test@example.com"})
      refute changeset.changes[:invitation_accepted_at]

      changeset = InvitationUser.user_identity_changeset(%InvitationUser{invitation_token: "token", invitation_accepted_at: DateTime.utc_now()}, @user_identity, %{}, %{email: "test@example.com"})
      refute changeset.changes[:invitation_accepted_at]

      changeset = InvitationUser.user_identity_changeset(%InvitationUser{invitation_token: "token"}, @user_identity, %{}, %{email: "test@example.com"})
      assert changeset.changes[:invitation_accepted_at]
    end
  end

  defmodule OverrideAssocUser do
    @moduledoc false
    use Ecto.Schema
    use Pow.Ecto.Schema
    use PowAssent.Ecto.Schema

    schema "users" do
      has_many :user_identities,
        MyApp.UserIdentities.UserIdentity,
        on_delete: :nothing

      pow_user_fields()

      timestamps()
    end
  end

  test "schema/2 with overridden fields" do
    user = %OverrideAssocUser{}

    assert Map.has_key?(user, :user_identities)
    assert %{on_delete: :nothing} = OverrideAssocUser.__schema__(:association, :user_identities)
  end

  test "schema/2 with no context user module name" do
    user = %PowAssent.NoContextUser{}

    assert Map.has_key?(user, :user_identities)
    assert %{queryable: PowAssent.UserIdentities.UserIdentity} = PowAssent.NoContextUser.__schema__(:association, :user_identities)
  end
end
