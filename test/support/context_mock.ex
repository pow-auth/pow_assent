defmodule PowAssent.Test.ContextMock do
  @moduledoc false
  use PowAssent.Ecto.UserIdentities.Context
  alias PowAssent.Test.Ecto.{UserIdentities.UserIdentity, Users.User}

  @user %User{id: 1, email: "test@example.com", password_hash: ""}
  @user_identity %UserIdentity{provider: "test_provider", uid: "1"}

  def get_user_by_provider_uid("test_provider", "1"), do: @user
  def get_user_by_provider_uid("test_provider", "new_user"), do: nil
  def get_user_by_provider_uid("test_provider", nil), do: @user

  def create(@user, "test_provider", "1"), do: {:ok, @user}
  def create(@user, "test_provider", nil), do: {:error, :changeset}

  def create_user("test_provider", "1", _params, _user_id_params), do: {:ok, @user}
  def create_user("test_provider", "new_user", _params, _user_id_params), do: {:ok, @user}
  def create_user("test_provider", nil, _params, _user_id_params), do: {:error, :changeset}

  def delete(@user, "test_provider"), do: {:ok, {1, nil}}
  def delete(:error, "test_provider"), do: {:error, :error}

  def all(@user), do: [@user_identity]
end
