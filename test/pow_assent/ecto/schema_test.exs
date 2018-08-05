module_raised_with = try do
  defmodule Pow.Test.Extension.Ecto.Schema.IvalidIdentity do
    use Ecto.Schema
    use PowAssent.Ecto.UserIdentities.Schema

    schema "user_identities" do
      pow_user_identity_schema()

      timestamps(updated_at: false)
    end
  end
rescue
  e in Pow.Config.ConfigError -> e.message
end
defmodule PowAssent.Ecto.SchemaTest do
  use PowAssent.Test.Ecto.TestCase
  doctest PowAssent.Ecto.Schema

  alias PowAssent.Test.Ecto.{Users.EmailConfirmUser, Users.User, Repo}

  test "user_schema/1" do
    user = %User{}

    assert Map.has_key?(user, :user_identities)
  end

  test "user_schema/1 requires :user" do
    assert unquote(module_raised_with) == "No :user configuration option found for user identity schema module."
  end

  @user_identity %{
    provider: "test_provider",
    uid: "1"
  }

  describe "user_identity_changeset/4" do
    test "validates required" do
      changeset = User.user_identity_changeset(%User{}, %{}, %{}, %{})

      assert [user_identity] = changeset.changes.user_identities
      assert user_identity.errors[:uid] == {"can't be blank", [validation: :required]}
      assert user_identity.errors[:provider] == {"can't be blank", [validation: :required]}
    end

    test "validates unique" do
      {:ok, _user} =
        %User{email: "test@example.com"}
        |> Ecto.Changeset.cast(%{"user_identities" => [@user_identity]}, [])
        |> Ecto.Changeset.cast_assoc(:user_identities)
        |> Repo.insert()

      assert {:error, changeset} =
        %User{email: "john.doe@example.com", name: "John Doe"}
        |> User.user_identity_changeset(@user_identity, %{}, %{})
        |> Repo.insert()

      assert [user_identity] = changeset.changes.user_identities
      assert user_identity.errors[:uid_provider] == {"has already been taken", []}
    end

    test "sets :email_confirmed_at when provided as attrs" do
      changeset = EmailConfirmUser.user_identity_changeset(%EmailConfirmUser{}, @user_identity, %{}, %{email: "test@example.com"})
      refute changeset.changes[:email_confirmed_at]

      changeset = EmailConfirmUser.user_identity_changeset(%EmailConfirmUser{}, @user_identity, %{email: "test@example.com"}, %{})
      assert changeset.changes[:email_confirmed_at]

      changeset = User.user_identity_changeset(%User{}, @user_identity, %{email: "test@example.com"}, %{})
      refute changeset.changes[:email_confirmed_at]
    end
  end
end
