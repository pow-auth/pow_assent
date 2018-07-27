defmodule PowAssent.Phoenix.Messages do
  @moduledoc false
  use Pow.Phoenix.Messages

  def signed_in(_conn, provider), do: gettext("Welcome! You've signed in with %{provider}.", provider: provider)
  def could_not_sign_in(_conn), do: gettext("Could not sign in. Please try again.")

  def user_has_been_created(_conn), do: gettext("Welcome! Your account has been created.")
  def account_already_bound_to_other_user(_conn, provider), do: gettext("The %{provider} account is already bound to another user.", provider: provider)

  def authentication_has_been_removed(_conn, provider), do: gettext("Authentication with %{provider} has been removed", provider: provider)
  def identity_cannot_be_removed_missing_user_password(_conn), do: gettext("Authentication cannot be removed until you've entered a password for your account.")

  def invalid_request(_conn), do: gettext("Invalid Request.")

  def login_with_provider(_conn, provider), do: gettext("Sign in with %{provider}", provider: provider)
  def remove_provider_authentication(_conn, provider), do: gettext("Remove %{provider} authentication", provider: provider)

  def gettext(msgid, opts) do
    Enum.reduce(opts, msgid, fn {key, value}, msg ->
      String.replace(msg, "%{#{key}}", value)
    end)
  end
  def gettext(msgid), do: msgid

  # def gettext(msgid, bindings \\ %{}) do
  #   Gettext.dgettext(backend, "pow_assent", msgid, bindings)
  # end
end
