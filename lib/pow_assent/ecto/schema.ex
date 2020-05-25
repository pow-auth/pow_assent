defmodule PowAssent.Ecto.Schema do
  @moduledoc """
  Handles the Ecto schema for user.

  `user_id_attrs` is provided by the user in a registration step.

  ## Usage

  Configure `lib/my_project/users/user.ex` the following way:

      defmodule MyApp.Users.User do
        use Ecto.Schema
        use Pow.Ecto.Schema
        use PowAssent.Ecto.Schema

        schema "users" do
          field :custom_field, :string

          pow_user_fields()

          timestamps()
        end

        def changeset(user_or_changeset, attrs) do
          user_or_changeset
          |> Ecto.Changeset.cast(attrs, [:custom_field])
          |> pow_changeset(attrs)
        end

        def identity_changeset(user_or_changeset, identity, attrs, user_id_attrs) do
          user_or_changeset
          |> Ecto.Changeset.cast(attrs, [:custom_field])
          |> pow_assent_identity_changeset(identity, attrs, user_id_attrs)
        end
      end
  """
  alias Ecto.{Changeset, Schema}
  alias Pow.UUID

  @callback identity_changeset(Schema.t() | Changeset.t(), Schema.t(), map(), map() | nil) :: Changeset.t()

  @doc false
  defmacro __using__(_config) do
    quote do
      @behaviour unquote(__MODULE__)

      @spec identity_changeset(Schema.t() | Changeset.t(), Schema.t(), map(), map() | nil) :: Changeset.t()
      def identity_changeset(user_or_changeset, identity, attrs, user_id_attrs), do: pow_assent_identity_changeset(user_or_changeset, identity, attrs, user_id_attrs)

      @spec pow_assent_identity_changeset(Schema.t() | Changeset.t(), Schema.t(), map(), map() | nil) :: Changeset.t()
      def pow_assent_identity_changeset(user_or_changeset, identity, attrs, user_id_attrs) do
        unquote(__MODULE__).changeset(user_or_changeset, identity, attrs, user_id_attrs, @pow_config)
      end

      unquote(__MODULE__).__has_many__()

      defoverridable unquote(__MODULE__)
    end
  end

  @doc false
  defmacro __has_many__() do
    quote do
      @pow_assocs {:has_many, :identities, unquote(__MODULE__).__identities_module__(__MODULE__), foreign_key: :user_id, on_delete: :delete_all}
    end
  end

  @doc false
  def __identities_module__(module) do
    module
    |> Module.split()
    |> Enum.reverse()
    |> case do
      [_schema, base] -> [base]
      [_schema, _context | rest] -> rest
    end
    |> Enum.reverse()
    |> Enum.concat([Users, UserIdentity])
    |> Module.concat()
  end

  @doc """
  Changeset for creating or updating users with a user identity.

  Only `Pow.Ecto.Schema.Changeset.user_id_field_changeset/3` is used for
  validation as password is not required.
  """
  @spec changeset(Schema.t() | Changeset.t(), Schema.t(), map(), map() | nil, Config.t()) :: Changeset.t()
  def changeset(user_or_changeset, identity, attrs, user_id_attrs, _config) do
    user_or_changeset
    |> Changeset.change()
    |> maybe_accept_invitation()
    |> user_id_field_changeset(attrs, user_id_attrs)
    |> maybe_email_confirmation_changeset(attrs)
    |> Changeset.cast(%{identities: [identity]}, [])
    |> Changeset.cast_assoc(:identities)
  end

  defp maybe_accept_invitation(%Changeset{data: %user_mod{invitation_token: token, invitation_accepted_at: nil} = changeset}) when not is_nil(token) do
    accepted_at = Pow.Ecto.Schema.__timestamp_for__(user_mod, :invitation_accepted_at)

    Changeset.change(changeset, invitation_accepted_at: accepted_at)
  end
  defp maybe_accept_invitation(changeset), do: changeset

  defp user_id_field_changeset(changeset, attrs, nil), do: changeset.data.__struct__.pow_user_id_field_changeset(changeset, attrs)
  defp user_id_field_changeset(changeset, _attrs, user_id_attrs), do: changeset.data.__struct__.pow_user_id_field_changeset(changeset, user_id_attrs)

  defp maybe_email_confirmation_changeset(%Changeset{data: %{unconfirmed_email: _any}} = changeset, attrs) do
    email = Changeset.get_change(changeset, :email)

    case email_verified?(email, attrs) do
      true  -> confirm_email_changeset(changeset)
      false -> email_confirmation_token_changeset(changeset)
    end
  end
  defp maybe_email_confirmation_changeset(changeset, _attrs), do: changeset

  defp confirm_email_changeset(%Changeset{data: %user_mod{}} = changeset) do
    confirmed_at = Pow.Ecto.Schema.__timestamp_for__(user_mod, :email_confirmed_at)

    Changeset.change(changeset, email_confirmed_at: confirmed_at)
  end

  defp email_confirmation_token_changeset(changeset) do
    changeset
    |> Changeset.put_change(:email_confirmation_token, UUID.generate())
    |> Changeset.unique_constraint(:email_confirmation_token)
  end

  defp email_verified?(email, %{"email" => email, "email_verified" => true}), do: true
  defp email_verified?(email, %{email: email, email_verified: true}), do: true
  defp email_verified?(_email, _attrs), do: false
end
