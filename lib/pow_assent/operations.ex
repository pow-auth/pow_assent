defmodule PowAssent.Operations do
  @moduledoc """
  Operation methods that glues operation calls to context module.

  A custom context module can be used instead of the default
  `PowAssent.Ecto.UserIdentities.Context` if a `:user_identities_context` key
  is passed in the configuration.
  """
  alias Pow.Config
  alias PowAssent.Ecto.UserIdentities.Context

  @doc """
  Retrieve a user with the strategy provider name and uid.

  This calls `Pow.Ecto.UserIdentities.Context.get_user_by_provider_uid/3` or
  `get_user_by_provider_uid/2` on a custom context module.
  """
  @spec get_user_by_provider_uid(Config.t(), binary(), binary()) :: map() | nil | no_return
  def get_user_by_provider_uid(config, provider, uid) do
    case context_module(config) do
      Context -> Context.get_user_by_provider_uid(config, provider, uid)
      module  -> module.get_user_by_provider_uid(provider, uid)
    end
  end

  @doc """
  Creates user identity for the user and strategy provider name and uid.

  This calls `Pow.Ecto.UserIdentities.Context.create/4` or
  `create/3` on a custom context module.
  """
  @spec create(Config.t(), map(), binary(), binary()) :: {:ok, map()} | {:error, {:bound_to_different_user, map()}} | {:error, map()} | no_return
  def create(config, user, provider, uid) do
    case context_module(config) do
      Context -> Context.create(config, user, provider, uid)
      module  -> module.create(user, provider, uid)
    end
  end

  @doc """
  Creates user with user identity with the provided user params.

  This calls `Pow.Ecto.UserIdentities.Context.create_user/5` or
  `create_user/4` on a custom context module.
  """
  @spec create_user(Config.t(), binary(), binary(), map(), map()) :: {:ok, map()} | {:error, {:bound_to_different_user | :missing_user_id_field, map()}} | {:error, map()} | no_return
  def create_user(config, provider, uid, params, user_id_params) do
    case context_module(config) do
      Context -> Context.create_user(config, provider, uid, params, user_id_params)
      module  -> module.create_user(provider, uid, params, user_id_params)
    end
  end

  @doc """
  Deletes the user identity for user and strategy provider name.

  This calls `Pow.Ecto.UserIdentities.Context.delete/3` or
  `delete/2` on a custom context module.
  """
  @spec delete(Config.t(), map(), binary()) :: {:ok, {number(), nil}} | {:error, {:no_password, map()}} | no_return
  def delete(config, user, provider) do
    case context_module(config) do
      Context -> Context.delete(config, user, provider)
      module  -> module.delete(user, provider)
    end
  end

  @doc """
  Lists all user identity associations for user.

  This calls `Pow.Ecto.UserIdentities.Context.all/2` or
  `all/1` on a custom context module.
  """
  @spec all(Config.t(), map()) :: [map()] | no_return
  def all(config, user) do
    case context_module(config) do
      Context -> Context.all(config, user)
      module  -> module.all(user)
    end
  end

  defp context_module(config) do
    Config.get(config, :user_identities_context, Context)
  end
end
