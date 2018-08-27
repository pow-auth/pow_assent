defmodule PowAssent.Test.ContextMock do
  @moduledoc false
  use PowAssent.Ecto.UserIdentities.Context
  alias PowAssent.Test.Ecto.{UserIdentities.UserIdentity, Users.User}

  @user %User{id: 1, email: "test@example.com", password_hash: ""}
  @user_identity %UserIdentity{provider: "test_provider", uid: "1"}

  def get_user_by_provider_uid("test_provider", "existing_user"), do: @user
  def get_user_by_provider_uid("test_provider", "new_user"), do: nil

  def create(%User{id: :loaded}, "test_provider", "new_identity"), do: {:ok, :new_identity}
  def create(%User{id: :bound_to_different_user}, "test_provider", "new_identity"), do: {:error, {:bound_to_different_user, %{}}}

  def create_user("test_provider", "new_user", %{"email" => ""}, _user_id_params), do: {:error, {:missing_user_id_field, %{}}}
  def create_user("test_provider", "new_user", _params, _user_id_params), do: {:ok, %{@user | id: :new_user}}
  def create_user("test_provider", "different_user", _params, _user_id_params), do: {:error, {:bound_to_different_user, %{}}}

  def delete(@user, "test_provider"), do: {:ok, {1, nil}}
  def delete(:error, "test_provider"), do: {:error, :error}

  def all(@user), do: [@user_identity]

  def user, do: @user
end
