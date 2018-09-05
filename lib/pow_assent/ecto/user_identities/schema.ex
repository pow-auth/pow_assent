defmodule PowAssent.Ecto.UserIdentities.Schema do
  @moduledoc """
  Handles the Ecto schema for user identity.

  A default `changeset/2` method is created, but can be overridden with a
  custom `changeset/2` method.

  ## Usage

  Configure `lib/my_project/user_identities/user_identity.ex` the following way:

      defmodule MyApp.UserIdentities.UserIdentity do
        use Ecto.Schema
        use PowAssent.Ecto.UserIdentities.Schema,
          user: MyApp.Users.User

        schema "user_identities" do
          pow_assent_user_identity_fields()

          timestamps(updated_at: false)
        end

        def changeset(user_identity_or_changeset, attrs) do
          pow_assent_changeset(user_identity_or_changeset, attrs)
        end
      end

  ## Configuration options

    * `:user` - the user schema module to use in the `belongs_to` association.
  """
  alias Ecto.Changeset
  alias Pow.Config

  @callback changeset(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()

  @doc false
  defmacro __using__(config) do
    user_mod = Config.get(config, :user) || raise_no_user_error()

    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__), only: [pow_assent_user_identity_fields: 0]

      @pow_user_mod unquote(user_mod)
      @pow_assent_config unquote(config)

      @spec changeset(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
      def changeset(user_identity_or_changeset, attrs),
        do: pow_assent_changeset(user_identity_or_changeset, attrs)

      @spec pow_assent_changeset(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
      def pow_assent_changeset(user_identity_or_changeset, attrs) do
        unquote(__MODULE__).changeset(user_identity_or_changeset, attrs, unquote(config))
      end

      defoverridable unquote(__MODULE__)
    end
  end

  @doc """
  Macro for adding user identity schema fields.
  """
  @spec pow_assent_user_identity_fields :: Macro.t()
  defmacro pow_assent_user_identity_fields do
    quote do
      belongs_to :user, @pow_user_mod

      for {name, type, opts} <- unquote(__MODULE__).Fields.attrs(@pow_assent_config) do
        field(name, type, opts)
      end
    end
  end

  @doc """
  Validates a user identity.
  """
  def changeset(user_identity_or_changeset, params, _config) do
    user_identity_or_changeset
    |> Changeset.cast(params, [:provider, :uid, :user_id])
    |> Changeset.validate_required([:provider, :uid])
    |> Changeset.assoc_constraint(:user)
    |> Changeset.unique_constraint(:uid_provider, name: :user_identities_uid_provider_index)
  end

  @spec raise_no_user_error :: no_return
  defp raise_no_user_error do
    Config.raise_error("No :user configuration option found for user identity schema module.")
  end
end
