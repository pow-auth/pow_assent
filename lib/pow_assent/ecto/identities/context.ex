defmodule PowAssent.Ecto.Identities.Context do
  @moduledoc """
  Handles pow assent user identity context for user identities.

  ## Usage

  This module will be used by PowAssent by default. If you wish to have control
  over context methods, you can do configure
  `LIB_PATH/user_identities.ex` the following way:

      defmodule MyApp.UserIdentities do
        use PowAssent.Ecto.Identities.Context,
          repo: MyApp.Repo,
          user: MyApp.Users.User

        def all(user) do
          pow_assent_all(user)
        end
      end

  Remember to update the PowAssent configuration with
  `identities_context: MyApp.Identities`.

  The following Pow methods can be accessed:

    * `pow_assent_get_user_by_provider_uid/3`
    * `pow_assent_upsert/2`
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

  @type changeset :: map()
  @type user :: map()
  @type identity :: map()
  @type user_params :: map()
  @type identity_params :: map()
  @type user_id_params :: map()

  @callback get_user_by_provider_uid(binary(), binary()) :: user() | nil
  @callback upsert(user(), identity_params()) ::
              {:ok, identity()}
              | {:error, {:bound_to_different_user, changeset()}}
              | {:error, changeset()}
  @callback create_user(identity_params(), user_params(), user_id_params() | nil) ::
              {:ok, user()}
              | {:error, {:bound_to_different_user | :invalid_user_id_field, changeset()}}
              | {:error, changeset()}
  @callback delete(user(), binary()) ::
              {:ok, {number(), nil}} | {:error, {:no_password, changeset()}}
  @callback all(user()) :: [identity()]

  # TODO: Remove by 0.4.0
  @callback create(user(), identity_params()) :: any()

  @doc false
  defmacro __using__(config) do
    quote do
      @behaviour unquote(__MODULE__)

      @pow_config unquote(config)

      def get_user_by_provider_uid(provider, uid),
        do: pow_assent_get_user_by_provider_uid(provider, uid)
      def upsert(user, identity_params), do: pow_assent_upsert(user, identity_params)
      def create_user(identity_params, user_params, user_id_params),
        do: pow_assent_create_user(identity_params, user_params, user_id_params)
      def delete(user, provider), do: pow_assent_delete(user, provider)
      def all(user), do: pow_assent_all(user)

      def pow_assent_get_user_by_provider_uid(provider, uid) do
        unquote(__MODULE__).get_user_by_provider_uid(provider, uid, @pow_config)
      end

      def pow_assent_upsert(user, identity_params) do
        unquote(__MODULE__).upsert(user, identity_params, @pow_config)
      end

      def pow_assent_create_user(identity_params, user_params, user_id_params) do
        unquote(__MODULE__).create_user(identity_params, user_params, user_id_params, @pow_config)
      end

      def pow_assent_delete(user, provider) do
        unquote(__MODULE__).delete(user, provider, @pow_config)
      end

      def pow_assent_all(user) do
        unquote(__MODULE__).all(user, @pow_config)
      end

      # TODO: Remove by 0.4.0
      @deprecated "Please use `upsert/2` instead"
      defdelegate create(user, identity_params), to: __MODULE__, as: :upsert

      # TODO: Remove by 0.4.0
      @deprecated "Please use `pow_assent_upsert/2` instead"
      defdelegate pow_assent_create(user, identity_params), to: __MODULE__, as: :pow_assent_upsert

      defoverridable unquote(__MODULE__)
    end
  end

  @doc """
  Finds a user based on the provider and uid.

  User schema module and repo module will be fetched from the config.
  """
  @spec get_user_by_provider_uid(binary(), binary() | integer(), Config.t()) :: user() | nil
  def get_user_by_provider_uid(provider, uid, config) when is_integer(uid),
    do: get_user_by_provider_uid(provider, Integer.to_string(uid), config)
  def get_user_by_provider_uid(provider, uid, config) do
    opts = repo_opts(config, [:prefix])

    config
    |> identity_schema_mod()
    |> where([i], i.provider == ^provider and i.uid == ^uid)
    |> join(:left, [i], i in assoc(i, :user))
    |> select([_, u], u)
    |> repo!(config).one(opts)
  end

  # TODO: Remove by 0.4.0
  @doc false
  @deprecated "Use `upsert/3` instead"
  @spec create(user(), identity_params(), Config.t()) :: {:ok, identity()} | {:error, {:bound_to_different_user, changeset()}} | {:error, changeset()}
  def create(user, identity_params, config), do: upsert(user, identity_params, config)

  @doc """
  Upserts a user identity.

  If a matching user identity already exists for the user, the identity will be updated,
  otherwise a new identity is inserted.

  Repo module will be fetched from config.
  """
  @spec upsert(user(), identity_params(), Config.t()) :: {:ok, identity()} | {:error, {:bound_to_different_user, changeset()}} | {:error, changeset()}
  def upsert(user, identity_params, config) do
    params                                   = convert_params(identity_params)
    {uid_provider_params, additional_params} = Map.split(params, ["uid", "provider"])

    user
    |> get_for_user(uid_provider_params, config)
    |> case do
      nil      -> insert_identity(user, params, config)
      identity -> update_identity(identity, additional_params, config)
    end
    |> identity_bound_different_user_error()
  end

  defp identity_bound_different_user_error({:error, %{errors: errors} = changeset}) do
    case unique_constraint_error?(errors, :uid) do
      true  -> {:error, {:bound_to_different_user, changeset}}
      false -> {:error, changeset}
    end
  end
  defp identity_bound_different_user_error(any), do: any

  defp convert_params(params) when is_map(params) do
    params
    |> Enum.map(&convert_param/1)
    |> :maps.from_list()
  end

  defp convert_param({:uid, value}), do: convert_param({"uid", value})
  defp convert_param({"uid", value}) when is_integer(value), do: convert_param({"uid", Integer.to_string(value)})
  defp convert_param({key, value}) when is_atom(key), do: {Atom.to_string(key), value}
  defp convert_param({key, value}) when is_binary(key), do: {key, value}

  defp insert_identity(user, identity_params, config) do
    identity = Ecto.build_assoc(user, :identities)

    identity
    |> identity.__struct__.changeset(identity_params)
    |> Context.do_insert(config)
  end

  defp update_identity(identity, additional_params, config) do
    identity
    |> identity.__struct__.changeset(additional_params)
    |> Context.do_update(config)
  end

  defp get_for_user(user, %{"uid" => uid, "provider" => provider}, config) do
    identity = Ecto.build_assoc(user, :identities).__struct__

    repo!(config).get_by(identity, [user_id: user.id, provider: provider, uid: uid], repo_opts(config, [:prefix]))
  end

  @doc """
  Creates a user with user identity.

  User schema module and repo module will be fetched from config.
  """
  @spec create_user(identity_params(), user_params(), user_id_params() | nil, Config.t()) :: {:ok, user()} | {:error, {:bound_to_different_user | :invalid_user_id_field, changeset()}} | {:error, changeset()}
  def create_user(identity_params, user_params, user_id_params, config) do
    params   = convert_params(identity_params)
    user_mod = user!(config)

    user_mod
    |> struct()
    |> user_mod.identity_changeset(params, user_params, user_id_params)
    |> Context.do_insert(config)
    |> user_identity_bound_different_user_error()
    |> invalid_user_id_error(config)
  end

  defp user_identity_bound_different_user_error({:error, %{changes: %{identities: [%{errors: errors}]}} = changeset}) do
    case unique_constraint_error?(errors, :uid) do
      true  -> {:error, {:bound_to_different_user, changeset}}
      false -> {:error, changeset}
    end
  end
  defp user_identity_bound_different_user_error(any), do: any

  defp unique_constraint_error?(errors, field) do
    Enum.find_value(errors, false, fn
      {^field, {_msg, [constraint: :unique, constraint_name: _name]}} -> true
      _any                                                            -> false
    end)
  end

  defp invalid_user_id_error({:error, %{errors: errors} = changeset}, config) do
    user_mod      = user!(config)
    user_id_field = user_mod.pow_user_id_field()

    Enum.find_value(errors, {:error, changeset}, fn
      {^user_id_field, _error} -> {:error, {:invalid_user_id_field, changeset}}
      _any                     -> false
    end)
  end
  defp invalid_user_id_error(any, _config), do: any

  @doc """
  Deletes a user identity for the provider and user.

  Repo module will be fetched from config.
  """
  @spec delete(user(), binary(), Config.t()) ::
          {:ok, {number(), nil}} | {:error, {:no_password, changeset()}}
  def delete(user, provider, config) do
    user = repo!(config).preload(user, :identities, repo_opts(config, [:prefix]) ++ [force: true])

    user.identities
    |> Enum.split_with(&(&1.provider == provider))
    |> maybe_delete(user, config)
  end

  defp maybe_delete({identities, rest}, %{password_hash: password_hash} = user, config) when length(rest) > 0 or not is_nil(password_hash) do
    opts    = repo_opts(config, [:prefix])
    results =
      user
      |> Ecto.assoc(:identities)
      |> where([i], i.id in ^Enum.map(identities, &(&1.id)))
      |> repo!(config).delete_all(opts)

    {:ok, results}
  end
  defp maybe_delete(_any, user, _config) do
    changeset =
      user
      |> Changeset.change()
      |> Changeset.validate_required(:password_hash)

    {:error, {:no_password, changeset}}
  end

  @doc """
  Fetches all user identities for user.

  Repo module will be fetched from config.
  """
  @spec all(user(), Config.t()) :: [identity()]
  def all(user, config) do
    opts = repo_opts(config, [:prefix])

    user
    |> Ecto.assoc(:identities)
    |> repo!(config).all(opts)
  end

  defp identity_schema_mod(config) when is_list(config) do
    config
    |> user!()
    |> identity_schema_mod()
  end
  defp identity_schema_mod(user_mod) when is_atom(user_mod) do
    association = user_mod.__schema__(:association, :identities) || raise_no_identity_error()

    association.queryable
  end

  @spec raise_no_identity_error :: no_return
  defp raise_no_identity_error do
    Config.raise_error("The `:user` configuration option doesn't have a `:identities` association.")
  end

  defp repo_opts(config, opts) do
    config
    |> Config.get(:repo_opts, [])
    |> Keyword.take(opts)
  end

  defdelegate user!(config), to: Pow.Config
  defdelegate repo!(config), to: Pow.Config
end
