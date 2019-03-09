defmodule PowAssent.Test.UserIdentitiesMock do
  @moduledoc false
  use PowAssent.Ecto.UserIdentities.Context
  alias PowAssent.Test.Ecto.{UserIdentities.UserIdentity, Users.User}

  @user %User{id: 1, email: "test@example.com", password_hash: ""}
  @changeset_invalid_name %User{} |> Ecto.Changeset.cast(%{"name" => ""}, [:name]) |> Ecto.Changeset.validate_required([:name]) |> Map.put(:action, :create)
  @changeset_taken_email %User{} |> Ecto.Changeset.cast(%{"email" => "taken@example.com"}, [:email]) |> Ecto.Changeset.add_error(:email, "has already been taken") |> Map.put(:action, :create)
  @user_identity %UserIdentity{provider: "test_provider", uid: "1"}
  @created_user_with_identity %{@user | id: :new_user, user_identities: [%{@user_identity | uid: "new_user"}]}

  def get_user_by_provider_uid("test_provider", "existing_user"), do: @user
  def get_user_by_provider_uid("test_provider", "new_user"), do: nil

  def create(_user, "test_provider", "new_identity"), do: {:ok, %UserIdentity{id: :new_identity}}
  def create(_user, "test_provider", "identity_taken"), do: {:error, {:bound_to_different_user, Ecto.Changeset.change(%UserIdentity{})}}

  def create_user("test_provider", "identity_taken", _params, _user_id_params), do: {:error, {:bound_to_different_user, Ecto.Changeset.change(%UserIdentity{})}}
  def create_user("test_provider", "new_user", %{"name" => ""}, _user_id_params), do: {:error, @changeset_invalid_name}
  def create_user("test_provider", "new_user", %{"email" => ""}, _user_id_params), do: {:error, {:invalid_user_id_field, %{}}}
  def create_user("test_provider", "new_user", %{"email" => "taken@example.com"}, _user_id_params), do: {:error, {:invalid_user_id_field, @changeset_taken_email}}
  def create_user("test_provider", "new_user", _params, %{"email" => "foo@example.com"}), do: {:ok, %{@created_user_with_identity | email: "foo@example.com"}}
  def create_user("test_provider", "new_user", _params, %{"email" => "taken@example.com"}), do: {:error, {:invalid_user_id_field, @changeset_taken_email}}
  def create_user("test_provider", "new_user", _params, _user_id_params), do: {:ok, @created_user_with_identity}

  def delete(%User{}, "test_provider"), do: {:ok, {1, nil}}
  def delete(:error, "test_provider"), do: {:error, :error}
  def delete(:no_password, "test_provider"), do: {:error, {:no_password, nil}}

  def all(@user), do: [@user_identity]

  def user, do: @user
end
