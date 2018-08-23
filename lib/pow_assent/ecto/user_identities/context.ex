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

  Remember to update configuration with `users_context: MyApp.Users`.

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
  alias Pow.Config
  require Ecto.Query

  @type user :: map()
  @type user_identity :: map()

  @callback get_user_by_provider_uid(binary(), binary()) :: user() | nil
  @callback create(user(), binary(), binary()) ::
              {:ok, user()}
              | {:error, {:bound_to_different_user, map()}}
              | {:error, Changeset.t()}
  @callback create_user(binary(), binary(), map(), map()) ::
              {:ok, map()}
              | {:error, {:bound_to_different_user | :missing_user_id_field, Changeset.t()}}
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
        unquote(__MODULE__).get_user_by_provider_uid(@pow_config, provider, uid)
      end

      def pow_assent_create(user, provider, uid) do
        unquote(__MODULE__).create(@pow_config, user, provider, uid)
      end

      def pow_assent_create_user(provider, uid, params, user_id_params) do
        unquote(__MODULE__).create_user(@pow_config, provider, uid, params, user_id_params)
      end

      def pow_assent_delete(user, provider) do
        unquote(__MODULE__).delete(@pow_config, user, provider)
      end

      def pow_assent_all(user) do
        unquote(__MODULE__).all(@pow_config, user)
      end

      defoverridable unquote(__MODULE__)
    end
  end

  @doc """
  Finds a user based on the provider and uid.

  User schema module and repo module will be fetched from the config.
  """
  @spec get_user_by_provider_uid(Config.t(), binary(), binary()) :: user() | nil
  def get_user_by_provider_uid(config, provider, uid) do
    repo   = repo(config)
    struct = user_identity_struct(config)

    struct
    |> repo.get_by(provider: provider, uid: uid)
    |> repo.preload(:user)
    |> case do
      nil      -> nil
      identity -> identity.user
    end
  end

  @doc """
  Creates a user identity.

  User schema module and repo module will be fetched from config.
  """
  @spec create(Config.t(), user(), binary(), binary()) :: {:ok, user_identity()} | {:error, {:bound_to_different_user, map()}} | {:error, Changeset.t()}
  def create(config, user, provider, uid) do
    repo            = repo(config)
    user_identity   = Ecto.build_assoc(user, :user_identities)

    user_identity
    |> user_identity.__struct__.changeset(%{provider: provider, uid: uid})
    |> repo.insert()
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
  @spec create_user(Config.t(), binary(), binary(), map(), map()) :: {:ok, map()} | {:error, {:bound_to_different_user | :missing_user_id_field, Changeset.t()}} | {:error, Changeset.t()}
  def create_user(config, provider, uid, params, user_id_params \\ %{}) do
    repo          = repo(config)
    user_struct   = user_struct(config)
    user_identity = %{provider: provider, uid: uid}
    user          = struct(user_struct)
    user_id_field = user_struct.pow_user_id_field()

    user
    |> user_struct.user_identity_changeset(user_identity, params, user_id_params)
    |> repo.insert()
    |> case do
      {:error, %{changes: %{user_identities: [%{errors: [uid_provider: _]}]}} = changeset} ->
        {:error, {:bound_to_different_user, changeset}}

      {:error, %{errors: [{^user_id_field, _}]} = changeset} ->
        {:error, {:missing_user_id_field, changeset}}

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
  @spec delete(Config.t(), user(), binary()) ::
          {:ok, {number(), nil}} | {:error, {:no_password, Changeset.t()}}
  def delete(config, user, provider) do
    repo = repo(config)
    user = repo.preload(user, :user_identities, force: true)

    user.user_identities
    |> Enum.split_with(&(&1.provider == provider))
    |> maybe_delete(user, repo, config)
  end

  defp maybe_delete({user_identities, rest}, %{password_hash: password_hash}, repo, config) when length(rest) > 0 or not is_nil(password_hash) do
    user_identity = user_identity_struct(config)
    results       =
      user_identity
      |> Ecto.Query.where([u], u.id in ^Enum.map(user_identities, &(&1.id)))
      |> repo.delete_all()

    {:ok, results}
  end
  defp maybe_delete(_any, user, _repo, _config) do
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
  @spec all(Config.t(), user()) :: [map()]
  def all(config, user) do
    repo   = repo(config)

    user
    |> Ecto.assoc(:user_identities)
    |> repo.all()
  end

  defp user_identity_struct(config) do
    association = user_struct(config).__schema__(:association, :user_identities) || raise_no_user_identity_error()

    association.queryable
  end

  @spec raise_no_user_identity_error :: no_return
  defp raise_no_user_identity_error do
    Config.raise_error("The `:user` configuration option doesnt' have a `:user_identities` association.")
  end

  def user_struct(config), do: Pow.Ecto.Context.user_schema_mod(config)
  def repo(config), do: Pow.Ecto.Context.repo(config)
end
