defmodule PowAssent.Phoenix.Messages do
  @moduledoc false

  alias Phoenix.Naming
  alias Plug.Conn
  alias PowAssent.Phoenix.Messages

  @type message :: Messages.message()

  @spec signed_in(Conn.t()) :: message()
  def signed_in(_conn), do: nil

  @spec could_not_sign_in(Conn.t()) :: message()
  def could_not_sign_in(_conn),
    do: "Something went wrong, and you couldn't be signed in. Please try again."

  @spec user_has_been_created(Conn.t()) :: message()
  def user_has_been_created(_conn), do: nil

  @spec account_already_bound_to_other_user(Conn.t()) :: message()
  def account_already_bound_to_other_user(conn),
    do: interpolate("The %{provider} account is already bound to another user.", provider: Naming.humanize(conn.params["provider"]))

  @spec authentication_has_been_removed(Conn.t()) :: message()
  def authentication_has_been_removed(conn),
    do: interpolate("Authentication with %{provider} has been removed", provider: Naming.humanize(conn.params["provider"]))

  @spec identity_cannot_be_removed_missing_user_password(Conn.t()) :: message()
  def identity_cannot_be_removed_missing_user_password(_conn),
    do: "Authentication cannot be removed until you've entered a password for your account."

  @spec invalid_request(Conn.t()) :: message()
  def invalid_request(_conn), do: "Invalid Request."

  @spec login_with_provider(Conn.t()) :: message()
  def login_with_provider(conn),
    do: interpolate("Sign in with %{provider}", provider: Naming.humanize(conn.params["provider"]))

  @spec remove_provider_authentication(Conn.t()) :: message()
  def remove_provider_authentication(conn),
    do: interpolate("Remove %{provider} authentication", provider: Naming.humanize(conn.params["provider"]))

  # Simple mock method for interpolations
  defp interpolate(msg, opts) do
    Enum.reduce(opts, msg, fn {key, value}, msg ->
      token = "%{#{key}}"

      case String.contains?(msg, token) do
        true  -> String.replace(msg, token, to_string(value), global: false)
        false -> msg
      end
    end)
  end
end
