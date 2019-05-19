defmodule PowAssent.Test.UserIdentitiesMock do
  @moduledoc false
  use PowAssent.Ecto.UserIdentities.Context
  alias PowAssent.Test.Ecto.{UserIdentities.UserIdentity, Users.User}

  @provider "test_provider"

  @user %User{id: 1, email: "test@example.com", password_hash: ""}
  @user_identity %UserIdentity{provider: @provider, uid: "1"}

  @new_user_identity_params %{"provider" => @provider, "uid" => "new_user"}
  @taken_user_identity_params %{"provider" => @provider, "uid" => "identity_taken"}

  @created_user_with_identity %{@user | id: :new_user, user_identities: [%{@user_identity | uid: "new_user"}]}
  @taken_user_id_changeset Ecto.Changeset.add_error(Ecto.Changeset.change(%User{}), :email, "has already been taken")

  def get_user_by_provider_uid(@provider, "existing_user"), do: @user
  def get_user_by_provider_uid(@provider, "new_user"), do: nil

  def create(_user, %{"provider" => @provider, "uid" => "new_identity"}), do: {:ok, %{@user_identity | id: :new_identity}}
  def create(user, @taken_user_identity_params), do: {:error, {:bound_to_different_user, %{User.changeset(user, @taken_user_identity_params) | action: :create}}}

  def create_user(@taken_user_identity_params, params, _user_id_params), do: {:error, {:bound_to_different_user, UserIdentity.changeset(%UserIdentity{}, params)}}
  def create_user(@new_user_identity_params, %{"name" => ""} = params, _user_id_params), do: {:error, %{User.changeset(%User{}, params) | action: :create}}
  def create_user(@new_user_identity_params, %{"email" => ""} = params, _user_id_params), do: {:error, {:invalid_user_id_field, %{User.changeset(%User{}, params) | action: :create}}}
  def create_user(@new_user_identity_params, %{"email" => "taken@example.com"} = params, _user_id_params), do: {:error, {:invalid_user_id_field, %{User.changeset(@taken_user_id_changeset, params) | action: :create}}}
  def create_user(@new_user_identity_params, _params, %{"email" => "taken@example.com"} = user_id_params), do: {:error, {:invalid_user_id_field, %{User.changeset(@taken_user_id_changeset, user_id_params) | action: :create}}}
  def create_user(@new_user_identity_params, _params, %{"email" => "foo@example.com"}), do: {:ok, %{@created_user_with_identity | email: "foo@example.com"}}
  def create_user(@new_user_identity_params, _params, _user_id_params), do: {:ok, @created_user_with_identity}

  def delete(%User{}, @provider), do: {:ok, {1, nil}}
  def delete(:error, @provider), do: {:error, :error}
  def delete(:no_password, @provider), do: {:error, {:no_password, nil}}

  def all(@user), do: [@user_identity]

  def user, do: @user
end
