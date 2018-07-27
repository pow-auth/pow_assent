defmodule PowAssent.Operations do
  @moduledoc """
  Operation methods that glues operation calls to context module.
  """
  alias Pow.Config
  alias PowAssent.Ecto.UserIdentities.Context

  @spec get_user_by_provider_uid(Config.t(), binary(), binary()) :: map() | nil | no_return
  def get_user_by_provider_uid(config, provider, uid) do
    case context_module(config) do
      Context -> Context.get_user_by_provider_uid(config, provider, uid)
      module  -> module.get_user_by_provider_uid(provider, uid)
    end
  end

  @spec create(Config.t(), map(), binary(), binary()) :: {:ok, map()} | {:error, {:bound_to_different_user, map()}} | {:error, map()} | no_return
  def create(config, user, provider, uid) do
    case context_module(config) do
      Context -> Context.create(config, user, provider, uid)
      module  -> module.create(user, provider, uid)
    end
  end

  @spec create_user(Config.t(), binary(), binary(), map(), map()) :: {:ok, map()} | {:error, {:bound_to_different_user | :missing_user_id_field, map()}} | {:error, map()} | no_return
  def create_user(config, provider, uid, params, user_id_params) do
    case context_module(config) do
      Context -> Context.create_user(config, provider, uid, params, user_id_params)
      module  -> module.create_user(provider, uid, params, user_id_params)
    end
  end

  @spec delete(Config.t(), map(), binary()) :: {:ok, {number(), nil}} | {:error, {:no_password, map()}} | no_return
  def delete(config, user, provider) do
    case context_module(config) do
      Context -> Context.delete(config, user, provider)
      module  -> module.delete(user, provider)
    end
  end

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
