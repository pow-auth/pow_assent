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
          |> pow_changeset(user, attrs)
        end

        def user_identity_changeset(user_or_changeset, user_identity, attrs, user_id_attrs) do
          user_or_changeset
          |> Ecto.Changeset.cast(attrs, [:custom_field])
          |> pow_assent_user_identity_changeset(user, user_identity, attrs, user_id_attrs)
        end
      end
  """
  alias Ecto.{Changeset, Schema}

  @callback user_identity_changeset(Schema.t() | Changeset.t(), Schema.t(), map(), map() | nil) :: Changeset.t()

  @doc false
  defmacro __using__(_config) do
    quote do
      @behaviour unquote(__MODULE__)

      @spec user_identity_changeset(Schema.t() | Changeset.t(), Schema.t(), map(), map() | nil) :: Changeset.t()
      def user_identity_changeset(user_or_changeset, user_identity, attrs, user_id_attrs), do: pow_assent_user_identity_changeset(user_or_changeset, user_identity, attrs, user_id_attrs)

      @spec pow_assent_user_identity_changeset(Schema.t() | Changeset.t(), Schema.t(), map(), map() | nil) :: Changeset.t()
      def pow_assent_user_identity_changeset(user_or_changeset, user_identity, attrs, user_id_attrs) do
        unquote(__MODULE__).changeset(user_or_changeset, user_identity, attrs, user_id_attrs, @pow_config)
      end

      unquote(__MODULE__).__has_many__()

      defoverridable unquote(__MODULE__)
    end
  end

  @doc false
  defmacro __has_many__() do
    quote do
      @pow_assocs {:has_many, :user_identities, unquote(__MODULE__).__user_identities_module__(__MODULE__), foreign_key: :user_id, on_delete: :delete_all}
    end
  end

  @doc false
  def __user_identities_module__(module) do
    module
    |> Module.split()
    |> Enum.reverse()
    |> case do
      [_schema, base] -> [base]
      [_schema, _context | rest] -> rest
    end
    |> Enum.reverse()
    |> Enum.concat([UserIdentities, UserIdentity])
    |> Module.concat()
  end

  @doc """
  Changeset for creating or updating users with a user identity.

  Only `Pow.Ecto.Schema.Changeset.user_id_field_changeset/3` is used for
  validation as password is not required.
  """
  @spec changeset(Schema.t() | Changeset.t(), Schema.t(), map(), map() | nil, Config.t()) :: Changeset.t()
  def changeset(user_or_changeset, user_identity, attrs, user_id_attrs, _config) do
    user_or_changeset
    |> Changeset.change()
    |> maybe_accept_invitation()
    |> user_id_field_changeset(attrs, user_id_attrs)
    |> Changeset.cast(%{user_identities: [user_identity]}, [])
    |> Changeset.cast_assoc(:user_identities)
  end

  defp maybe_accept_invitation(%Changeset{data: %user_mod{invitation_token: token, invitation_accepted_at: nil} = changeset}) when not is_nil(token) do
    accepted_at = Pow.Ecto.Schema.__timestamp_for__(user_mod, :invitation_accepted_at)

    Changeset.change(changeset, invitation_accepted_at: accepted_at)
  end
  defp maybe_accept_invitation(changeset), do: changeset

  defp user_id_field_changeset(changeset, attrs, nil) do
    changeset
    |> changeset.data.__struct__.pow_user_id_field_changeset(attrs)
    |> maybe_set_confirmed_at()
  end
  defp user_id_field_changeset(changeset, _attrs, user_id_attrs) do
    changeset.data.__struct__.pow_user_id_field_changeset(changeset, user_id_attrs)
  end

  defp maybe_set_confirmed_at(changeset) do
    case confirmable?(changeset) do
      true  -> PowEmailConfirmation.Ecto.Schema.confirm_email_changeset(changeset)
      false -> changeset
    end
  end

  defp confirmable?(changeset) do
    Map.has_key?(changeset.data, :email) and
    Map.has_key?(changeset.data, :email_confirmed_at) and
    !Map.get(changeset.data, :unconfirmed_email)
  end
end
