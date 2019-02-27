defmodule PowAssent.Operations do
  @moduledoc """
  Operation methods that glues operation calls to context module.

  A custom context module can be used instead of the default
  `PowAssent.Ecto.UserIdentities.Context` if a `:user_identities_context` key
  is passed in the configuration.
  """
  alias PowAssent.{Config, Ecto.UserIdentities.Context}

  @doc """
  Retrieve a user with the strategy provider name and uid.

  This calls `Pow.Ecto.UserIdentities.Context.get_user_by_provider_uid/3` or
  `get_user_by_provider_uid/2` on a custom context module.
  """
  @spec get_user_by_provider_uid(binary(), binary(), Config.t()) :: map() | nil | no_return
  def get_user_by_provider_uid(provider, uid, config) do
    case context_module(config) do
      Context -> Context.get_user_by_provider_uid(provider, uid, config)
      module  -> module.get_user_by_provider_uid(provider, uid)
    end
  end

  @doc """
  Creates user identity for the user and strategy provider name and uid.

  This calls `Pow.Ecto.UserIdentities.Context.create/4` or
  `create/3` on a custom context module.
  """
  @spec create(map(), binary(), binary(), Config.t()) :: {:ok, map()} | {:error, {:bound_to_different_user, map()}} | {:error, map()} | no_return
  def create(user, provider, uid, config) do
    case context_module(config) do
      Context -> Context.create(user, provider, uid, config)
      module  -> module.create(user, provider, uid)
    end
  end

  @doc """
  Creates user with user identity with the provided user params.

  This calls `Pow.Ecto.UserIdentities.Context.create_user/5` or
  `create_user/4` on a custom context module.
  """
  @spec create_user(binary(), binary(), map(), map(), Config.t()) :: {:ok, map()} | {:error, {:bound_to_different_user | :missing_user_id_field, map()}} | {:error, map()} | no_return
  def create_user(provider, uid, params, user_id_params, config) do
    case context_module(config) do
      Context -> Context.create_user(provider, uid, params, user_id_params, config)
      module  -> module.create_user(provider, uid, params, user_id_params)
    end
  end

  @doc """
  Deletes the user identity for user and strategy provider name.

  This calls `Pow.Ecto.UserIdentities.Context.delete/3` or
  `delete/2` on a custom context module.
  """
  @spec delete(map(), binary(), Config.t()) :: {:ok, {number(), nil}} | {:error, {:no_password, map()}} | no_return
  def delete(user, provider, config) do
    case context_module(config) do
      Context -> Context.delete(user, provider, config)
      module  -> module.delete(user, provider)
    end
  end

  @doc """
  Lists all user identity associations for user.

  This calls `Pow.Ecto.UserIdentities.Context.all/2` or
  `all/1` on a custom context module.
  """
  @spec all(map(), Config.t()) :: [map()] | no_return
  def all(user, config) do
    case context_module(config) do
      Context -> Context.all(user, config)
      module  -> module.all(user)
    end
  end

  defp context_module(config) do
    Config.get(config, :user_identities_context, Context)
  end
end
