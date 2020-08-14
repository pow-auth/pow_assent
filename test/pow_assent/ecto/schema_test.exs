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

    assert Map.has_key?(user, :identities)
    assert %{on_delete: on_delete, queryable: queryable} = User.__schema__(:association, :identities)
    assert on_delete == :delete_all
    assert queryable == PowAssent.Test.Ecto.Users.UserIdentity
  end

  @identity %{
    provider: "test_provider",
    uid: "1"
  }

  describe "identity_changeset/4" do
    test "validates required" do
      changeset = User.identity_changeset(%User{}, %{}, %{}, nil)

      assert [identity] = changeset.changes.identities
      assert identity.errors[:uid] == {"can't be blank", [validation: :required]}
      assert identity.errors[:provider] == {"can't be blank", [validation: :required]}
      assert changeset.errors[:name] == {"can't be blank", [validation: :required]}

      changeset = User.identity_changeset(%User{}, @identity, %{email: "test@example.com", name: "John Doe"}, nil)
      assert changeset.valid?
      assert changeset.changes[:name] == "John Doe"
    end

    test "validates unique" do
      {:ok, _user} =
        %User{email: "test@example.com"}
        |> Ecto.Changeset.cast(%{"identities" => [@identity]}, [])
        |> Ecto.Changeset.cast_assoc(:identities)
        |> Repo.insert()

      assert {:error, changeset} =
        %User{email: "john.doe@example.com", name: "John Doe"}
        |> User.identity_changeset(@identity, %{}, nil)
        |> Repo.insert()

      assert [identity] = changeset.changes.identities
      assert identity.errors[:uid] == {"has already been taken", [constraint: :unique, constraint_name: "user_identities_uid_provider_index"]}
    end

    test "uses case insensitive value for user id" do
      changeset = User.identity_changeset(%User{}, @identity, %{email: "Test@EXAMPLE.com", name: "John Doe"}, nil)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :email) == "test@example.com"
    end
  end

  defmodule UsernameUserWithEmail do
    @moduledoc false
    use Ecto.Schema
    use Pow.Ecto.Schema, user_id_field: :username
    use Pow.Extension.Ecto.Schema,
      extensions: [PowEmailConfirmation]
    use PowAssent.Ecto.Schema

    schema "users" do
      has_many :identities, PowAssent.Test.Ecto.Users.UserIdentity, foreign_key: :user_id, on_delete: :delete_all

      field :email, :string

      pow_user_fields()

      timestamps()
    end

    def identity_changeset(user_or_changeset, identity, attrs, user_id_attrs) do
      user_or_changeset
      |> Ecto.Changeset.cast(attrs, [:email])
      |> pow_assent_identity_changeset(identity, attrs, user_id_attrs)
    end
  end

  describe "identity_changeset/4 with PowEmailConfirmation" do
    test "sets :email_confirmed_at when provided as attrs" do
      provider_params = %{email: "test@example.com", email_verified: true, name: "John Doe"}

      changeset = User.identity_changeset(%User{}, @identity, provider_params, nil)
      assert changeset.changes[:email]
      refute changeset.changes[:email_confirmed_at]
      refute changeset.changes[:email_confirmation_token]

      changeset = UserConfirmEmail.identity_changeset(%UserConfirmEmail{}, @identity, provider_params, %{email: "foo@example.com"})
      assert changeset.changes[:email]
      refute changeset.changes[:email_confirmed_at]
      assert changeset.changes[:email_confirmation_token]

      changeset = UserConfirmEmail.identity_changeset(%UserConfirmEmail{}, @identity, provider_params, %{email: "test@example.com"})
      assert changeset.changes[:email]
      assert changeset.changes[:email_confirmed_at]
      refute changeset.changes[:email_confirmation_token]

      changeset = UserConfirmEmail.identity_changeset(%UserConfirmEmail{}, @identity, provider_params, nil)
      assert changeset.changes[:email]
      assert changeset.changes[:name] == "John Doe"
      assert changeset.changes[:email_confirmed_at]
      refute changeset.changes[:email_confirmation_token]

      changeset = UserConfirmEmail.identity_changeset(%UserConfirmEmail{}, @identity,  Map.delete(provider_params, :email_verified), nil)
      assert changeset.changes[:email]
      assert changeset.changes[:name] == "John Doe"
      refute changeset.changes[:email_confirmed_at]
      assert changeset.changes[:email_confirmation_token]
    end

    test "sets :email_confirmed_at when provided as attrs and :email is not user id field" do
      provider_params = %{email: "test@example.com", email_verified: true}

      changeset = UsernameUserWithEmail.identity_changeset(%UsernameUserWithEmail{}, @identity, Map.delete(provider_params, :email_verified), %{username: "john.doe"})
      assert changeset.changes[:email]
      refute changeset.changes[:email_confirmed_at]
      assert changeset.changes[:email_confirmation_token]

      changeset = UsernameUserWithEmail.identity_changeset(%UsernameUserWithEmail{}, @identity, provider_params, %{username: "john.doe"})
      assert changeset.changes[:username]
      assert changeset.changes[:email]
      assert changeset.changes[:email_confirmed_at]
      refute changeset.changes[:email_confirmation_token]
    end
  end

  describe "identity_changeset/4 with PowInvitation" do
    test "sets :invitation_accepted_at when is invited user" do
      changeset = InvitationUser.identity_changeset(%InvitationUser{}, @identity, %{}, %{email: "test@example.com"})
      refute changeset.changes[:invitation_accepted_at]

      changeset = InvitationUser.identity_changeset(%InvitationUser{invitation_token: "token", invitation_accepted_at: DateTime.utc_now()}, @identity, %{}, %{email: "test@example.com"})
      refute changeset.changes[:invitation_accepted_at]

      changeset = InvitationUser.identity_changeset(%InvitationUser{invitation_token: "token"}, @identity, %{}, %{email: "test@example.com"})
      assert changeset.changes[:invitation_accepted_at]
    end
  end

  defmodule OverrideAssocUser do
    @moduledoc false
    use Ecto.Schema
    use Pow.Ecto.Schema
    use PowAssent.Ecto.Schema

    schema "users" do
      has_many :identities,
        MyApp.Users.UserIdentity,
        on_delete: :nothing

      pow_user_fields()

      timestamps()
    end
  end

  test "schema/2 with overridden fields" do
    user = %OverrideAssocUser{}

    assert Map.has_key?(user, :identities)
    assert %{on_delete: on_delete, queryable: queryable} = OverrideAssocUser.__schema__(:association, :identities)
    assert on_delete == :nothing
    assert queryable == MyApp.Users.UserIdentity
  end

  test "schema/2 with no context user module name" do
    user = %PowAssent.NoContextUser{}

    assert Map.has_key?(user, :identities)
    assert %{queryable: queryable} = PowAssent.NoContextUser.__schema__(:association, :identities)
    assert queryable == PowAssent.UserIdentity
  end
end
