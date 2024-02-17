defmodule PowAssent.Phoenix.Messages do
  @moduledoc """
  Module that handles messages for PowAssent.

  To override messages from PowAssent, the method name has to start with the
  `pow_assent_`. So the `signed_in/1` method, should be written as
  `pow_assent_signed_in/1`.

  ## Usage

      defmodule MyAppWeb.Pow.Messages do
        use Pow.Phoenix.Messages
        use Pow.Extension.Phoenix.Messages,
          extensions: [PowAssent]

        import MyAppWeb.Gettext

        def pow_assent_signed_in(conn) do
          provider = Phoenix.Naming.humanize(conn.params["provider"])

          gettext("You've been signed in with %{provider}.")
        end
      end

  Remember to update Pow configuration with
  `messages_backend: MyAppWeb.Pow.Messages`.

  See `Pow.Extension.Phoenix.Messages` for more.
  """
  alias Phoenix.Naming

  @doc """
  Message for when user has signed in.

  Defaults to nil.
  """
  def signed_in(_conn), do: nil

  @doc """
  Message for when user couldn't be signed in.
  """
  def could_not_sign_in(_conn),
    do: "Something went wrong, and you couldn't be signed in. Please try again."

  @doc """
  Message for when user has signed up successfully.

  Defaults to nil.
  """
  def user_has_been_created(_conn), do: nil

  @doc """
  Message for when provider account already exists for another user.
  """
  def account_already_bound_to_other_user(conn),
    do: interpolate("The %{provider} account is already bound to another user.", provider: Naming.humanize(conn.params["provider"]))

  @doc """
  Message for when provider identity has been deleted for user.
  """
  def authentication_has_been_removed(conn),
    do: interpolate("Authentication with %{provider} has been removed", provider: Naming.humanize(conn.params["provider"]))

  @doc """
  Message for when user password is required to delete provider identity.
  """
  def identity_cannot_be_removed_missing_user_password(_conn),
    do: "Authentication cannot be removed until you've entered a password for your account."

  @doc """
  Message for invalid request.
  """
  def invalid_request(_conn), do: "Invalid Request."

  @doc """
  Message for provider login button.
  """
  #  TODO: Change function name to `log_in_with_provider` or `sign_in_with_provider`.
  def login_with_provider(conn),
    do: interpolate("Sign in with %{provider}", provider: Naming.humanize(conn.params["provider"]))

  @doc """
  Message for provider identity deletion button.
  """
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
