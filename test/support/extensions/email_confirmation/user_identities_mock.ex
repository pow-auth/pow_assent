defmodule PowAssent.Test.EmailConfirmation.UserIdentitiesMock do
  @moduledoc false
  use PowAssent.Ecto.UserIdentities.Context
  alias PowAssent.Test.EmailConfirmation.Users.User

  @user %User{id: 1, email: "test@example.com", email_confirmation_token: "token"}

  def get_user_by_provider_uid("test_provider", "new_user-missing_email_confirmation"), do: %{@user | email_confirmed_at: nil}

  def create_user("test_provider", "new_user", _params, %{"email" => "foo@example.com"}), do: {:ok, %{@user | email: "foo@example.com"}}
  def create_user("test_provider", "new_user", %{"email" => "foo@example.com"}, _user_params), do: {:ok, %{@user | email: "foo@example.com", email_confirmed_at: DateTime.utc_now()}}
end
