defmodule PowAssent.Ecto.UserIdentities.Context do
  @moduledoc """
  Handles pow user identity context for user identities.
  """
  alias Ecto.Changeset
  alias Pow.Config
  require Ecto.Query

  @callback get_user_by_provider_id(Config.t(), binary(), binary()) :: user() | nil
  @callback create(Config.t(), binary(), binary(), map(), user()) ::
              {:ok, user()}
              | {:error, {:bound_to_different_user, map()}}
              | {:error, Changeset.t()}
  @callback create_user(Config.t(), binary(), binary(), map(), map()) ::
              {:ok, map()}
              | {:error, {:bound_to_different_user | :missing_user_id_field, Changeset.t()}}
              | {:error, Changeset.t()}
  @callback delete(Config.t(), user(), binary()) ::
              {:ok, {number(), nil}} | {:error, {:no_password, Changeset.t()}}
  @callback all(Config.t(), user()) :: [map()]

  @type user :: map()
  @type user_identity :: map()

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
