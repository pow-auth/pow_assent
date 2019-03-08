defmodule PowAssent.Ecto.UserIdentities.Context do
  @moduledoc """
  Handles pow assent user identity context for user identities.

  ## Usage

  This module will be used by PowAssent by default. If you wish to have control
  over context methods, you can do configure
  `lib/my_project/user_identities/user_identities.ex` the following way:

      defmodule MyApp.UserIdentities do
        use PowAssent.Ecto.UserIdentities.Context,
          repo: MyApp.Repo,
          user: MyApp.Users.User

        def all(user) do
          pow_assent_all(user)
        end
      end

  Remember to update configuration with
  `user_identities_context: MyApp.UserIdentities`.

  The following Pow methods can be accessed:

    * `pow_assent_get_user_by_provider_id/3`
    * `pow_assent_create/4`
    * `pow_assent_create_user/4`
    * `pow_assent_delete/2`
    * `pow_assent_all/1`

  ## Configuration options

    * `:repo` - the ecto repo module (required)
    * `:user` - the user schema module (required)
  """
  alias Ecto.Changeset
  alias PowAssent.Config
  alias Pow.Ecto.Context
  import Ecto.Query

  @type user :: map()
  @type user_identity :: map()

  @callback get_user_by_provider_uid(binary(), binary()) :: user() | nil
  @callback create(user(), binary(), binary()) ::
              {:ok, user()}
              | {:error, {:bound_to_different_user, map()}}
              | {:error, Changeset.t()}
  @callback create_user(binary(), binary(), map(), map() | nil) ::
              {:ok, map()}
              | {:error, {:bound_to_different_user | :invalid_user_id_field, Changeset.t()}}
              | {:error, Changeset.t()}
  @callback delete(user(), binary()) ::
              {:ok, {number(), nil}} | {:error, {:no_password, Changeset.t()}}
  @callback all(user()) :: [map()]

  @doc false
  defmacro __using__(config) do
    quote do
      @behaviour unquote(__MODULE__)

      @pow_config unquote(config)

      def get_user_by_provider_uid(provider, uid),
        do: pow_assent_get_user_by_provider_uid(provider, uid)
      def create(user, provider, uid), do: pow_assent_create(user, provider, uid)
      def create_user(provider, uid, params, user_id_params),
        do: pow_assent_create_user(provider, uid, params, user_id_params)
      def delete(user, provider), do: pow_assent_delete(user, provider)
      def all(user), do: pow_assent_all(user)

      def pow_assent_get_user_by_provider_uid(provider, uid) do
        unquote(__MODULE__).get_user_by_provider_uid(provider, uid, @pow_config)
      end

      def pow_assent_create(user, provider, uid) do
        unquote(__MODULE__).create(user, provider, uid, @pow_config)
      end

      def pow_assent_create_user(provider, uid, params, user_id_params) do
        unquote(__MODULE__).create_user(provider, uid, params, user_id_params, @pow_config)
      end

      def pow_assent_delete(user, provider) do
        unquote(__MODULE__).delete(user, provider, @pow_config)
      end

      def pow_assent_all(user) do
        unquote(__MODULE__).all(user, @pow_config)
      end

      defoverridable unquote(__MODULE__)
    end
  end

  @doc """
  Finds a user based on the provider and uid.

  User schema module and repo module will be fetched from the config.
  """
  @spec get_user_by_provider_uid(binary(), binary(), Config.t()) :: user() | nil
  def get_user_by_provider_uid(provider, uid, config) do
    config
    |> user_identity_schema_mod()
    |> where([i], i.provider == ^provider and i.uid == ^uid)
    |> join(:left, [i], i in assoc(i, :user))
    |> select([_, u], u)
    |> repo(config).one()
  end

  @doc """
  Creates a user identity.

  User schema module and repo module will be fetched from config.
  """
  @spec create(user(), binary(), binary(), Config.t()) :: {:ok, user_identity()} | {:error, {:bound_to_different_user, map()}} | {:error, Changeset.t()}
  def create(user, provider, uid, config) do
    user_identity = Ecto.build_assoc(user, :user_identities)

    user_identity
    |> user_identity.__struct__.changeset(%{provider: provider, uid: uid})
    |> Context.do_insert(config)
    |> case do
      {:error, %{errors: [uid_provider: _]} = changeset} ->
        {:error, {:bound_to_different_user, changeset}}

      {:ok, user_identity} ->
        {:ok, user_identity}
    end
  end

  @doc """
  Creates a user with user identity.

  User schema module and repo module will be fetched from config.
  """
  @spec create_user(binary(), binary(), map(), map() | nil, Config.t()) :: {:ok, map()} | {:error, {:bound_to_different_user | :invalid_user_id_field, Changeset.t()}} | {:error, Changeset.t()}
  def create_user(provider, uid, params, user_id_params, config) do
    user_mod      = user_schema_mod(config)
    user_identity = %{provider: provider, uid: uid}
    user_id_field = user_mod.pow_user_id_field()

    user_mod
    |> struct()
    |> user_mod.user_identity_changeset(user_identity, params, user_id_params)
    |> Context.do_insert(config)
    |> case do
      {:error, %{changes: %{user_identities: [%{errors: [uid_provider: _]}]}} = changeset} ->
        {:error, {:bound_to_different_user, changeset}}

      {:error, %{errors: [{^user_id_field, _}]} = changeset} ->
        {:error, {:invalid_user_id_field, changeset}}

      {:error, changeset} ->
        {:error, changeset}

      {:ok, user} ->
        {:ok, user}
    end
  end

  @doc """
  Deletes a user identity for the provider and user.

  User schema module and repo module will be fetched from config.
  """
  @spec delete(user(), binary(), Config.t()) ::
          {:ok, {number(), nil}} | {:error, {:no_password, Changeset.t()}}
  def delete(user, provider, config) do
    repo = repo(config)
    user = repo.preload(user, :user_identities, force: true)

    user.user_identities
    |> Enum.split_with(&(&1.provider == provider))
    |> maybe_delete(user, repo)
  end

  defp maybe_delete({user_identities, rest}, %{password_hash: password_hash} = user, repo) when length(rest) > 0 or not is_nil(password_hash) do
    results =
      user
      |> Ecto.assoc(:user_identities)
      |> where([i], i.id in ^Enum.map(user_identities, &(&1.id)))
      |> repo.delete_all()

    {:ok, results}
  end
  defp maybe_delete(_any, user, _repo) do
    changeset =
      user
      |> Changeset.change()
      |> Changeset.validate_required(:password_hash)

    {:error, {:no_password, changeset}}
  end

  @doc """
  Fetches all user identities for user.

  User schema module and repo module will be fetched from config.
  """
  @spec all(user(), Config.t()) :: [map()]
  def all(user, config) do
    user
    |> Ecto.assoc(:user_identities)
    |> repo(config).all()
  end

  defp user_identity_schema_mod(config) when is_list(config) do
    config
    |> user_schema_mod()
    |> user_identity_schema_mod()
  end
  defp user_identity_schema_mod(user_mod) when is_atom(user_mod) do
    association = user_mod.__schema__(:association, :user_identities) || raise_no_user_identity_error()

    association.queryable
  end

  @spec raise_no_user_identity_error :: no_return
  defp raise_no_user_identity_error do
    Config.raise_error("The `:user` configuration option doesn't have a `:user_identities` association.")
  end

  defdelegate user_schema_mod(config), to: Pow.Ecto.Context
  defdelegate repo(config), to: Pow.Ecto.Context
end
