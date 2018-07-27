defmodule PowAssent.Test.Phoenix.MockRepo do
  @moduledoc false
  alias Ecto.Changeset
  alias PowAssent.Test.Ecto.UserIdentities.{EmailConfirmUserIdentity, UserIdentity}
  alias PowAssent.Test.Ecto.Users.{EmailConfirmUser, User}

  @user_identity %UserIdentity{user_id: 1, id: 1, provider: "test_provider", uid: "1"}
  @email_confirm_user_identity %EmailConfirmUserIdentity{user_id: 1, id: 1, provider: "test_provider", uid: "1"}

  def all(_), do: [@user_identity]

  def get_by(UserIdentity, provider: "test_provider", uid: "existing"), do: @user_identity
  def get_by(EmailConfirmUserIdentity, provider: "test_provider", uid: "user-missing-email-confirmation"), do: Map.put(@email_confirm_user_identity, :id, :with_missing_email_confirmation)
  def get_by(UserIdentity, provider: "test_provider", uid: "1"), do: nil

  def preload(%User{id: 1} = user, :user_identities, force: true), do: %{user | user_identities: []}
  def preload(%User{id: :with_user_identity} = user, :user_identities, force: true), do: %{user | user_identities: [@user_identity]}
  def preload(%User{id: :with_two_user_identities} = user, :user_identities, force: true), do: %{user | user_identities: [@user_identity, Map.put(@user_identity, :provider, "different_provider")]}

  def preload(%EmailConfirmUserIdentity{id: :with_missing_email_confirmation} = user_identity, :user), do: %{user_identity | user: %EmailConfirmUser{id: 1, email_confirmation_token: "token", email_confirmed_at: nil}}
  def preload(%UserIdentity{id: 1} = user_identity, :user), do: %{user_identity | user: %User{id: 1}}
  def preload(nil, :user), do: nil

  def insert(%{data: %UserIdentity{}, changes: %{uid: "duplicate"}} = changeset), do: {:error, %{Changeset.add_error(changeset, :uid_provider, "has already been taken", fields: [:provider, :uid]) | action: :insert}}
  def insert(%{changes: %{user_identities: [%{changes: %{provider: "test_provider", uid: "duplicate"}} = user_identity_changeset]}} = changeset) do
    user_identity_changeset = Changeset.add_error(user_identity_changeset, :uid_provider, "has already been taken", fields: [:provider, :uid])
    changeset = Changeset.change(changeset, user_identities: [user_identity_changeset])

    {:error, changeset}
  end
  def insert(%{changes: %{email: "taken@example.com"}} = changeset), do: {:error, %{Changeset.add_error(changeset, :email, "has already been taken") | action: :insert}}
  def insert(%{valid?: true} = changeset), do: {:ok, Changeset.apply_changes(changeset)}
  def insert(%{valid?: false} = changeset), do: {:error, %{changeset | action: :insert}}

  def delete_all(_), do: {:ok, {1, nil}}
end
