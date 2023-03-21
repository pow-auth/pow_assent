defmodule PowAssent.Config do
  @moduledoc """
  Methods to parse and modify configurations.
  """

  defmodule ConfigError do
    defexception [:message]
  end

  @type t :: Keyword.t()

  @doc """
  Gets the key value from the configuration.

  If not found, it'll fall back to environment config, and lastly to the
  default value which is `nil` if not specified.
  """
  @spec get(t(), atom(), any()) :: any()
  def get(config, key, default \\ nil) do
    case Keyword.get(config, key, :not_found) do
      :not_found -> get_env_config(config, key, default)
      value      -> value
    end
  end

  @doc """
  Puts a new key value to the configuration.
  """
  @spec put(t(), atom(), any()) :: t()
  def put(config, key, value) do
    Keyword.put(config, key, value)
  end

  defp get_env_config(config, key, default, env_key \\ :pow_assent) do
    config
    |> Keyword.get(:otp_app)
    |> case do
      nil     -> Application.get_all_env(env_key)
      otp_app -> Application.get_env(otp_app, env_key, [])
    end
    |> Keyword.get(key, default)
  end

  @doc """
  Gets the providers for the configuration.
  """
  @spec get_providers(t()) :: t()
  def get_providers(config), do: get(config, :providers, [])

  @doc """
  Merge new config for provider.

  The new config values are deep merged with the existing provider config. Any
  conflicting keys from the default config for the strategy will be fetched and
  the provider config deep merged unto it.
  """
  @spec merge_provider_config(t(), atom(), t()) :: t()
  def merge_provider_config(config, provider, new_provider_config) do
    provider_config =
      config
      |> get_provider_config(provider)
      |> deep_merge(new_provider_config)

    mod = Keyword.get(provider_config, :strategy)

    default_config =
      provider_config
      |> mod.default_config()
      |> Keyword.take(Keyword.keys(provider_config))

    updated_provider_config = deep_merge(default_config, provider_config)

    updated_config =
      config
      |> get_providers()
      |> Keyword.put(provider, updated_provider_config)

    put(config, :providers, updated_config)
  end

  defp deep_merge([{k1, _} | _] = left, [{k2, _} | _] = right) when is_atom(k1) and is_atom(k2) do
    Keyword.merge(left, right, fn _k, left, right ->
      deep_merge(left, right)
    end)
  end
  defp deep_merge(_left, right), do: right

  @doc """
  Gets the provider configuration from the provided configuration.
  """
  @spec get_provider_config(t(), atom()) :: t() | no_return
  def get_provider_config(config, provider) do
    config
    |> get_providers()
    |> Keyword.get(provider)
    |> Kernel.||(raise_no_provider_config_error(provider))
    |> add_global_config(config)
  end

  defp add_global_config(provider_config, config) do
    [
      :http_adapter,
      :json_adapter,
      :jwt_adapter
    ]
    |> Enum.map(&{&1, get(config, &1)})
    |> Enum.reject(&is_nil(elem(&1, 1)))
    |> Keyword.merge(provider_config)
  end

  @doc false
  @spec raise_no_provider_config_error(any()) :: no_return
  def raise_no_provider_config_error(provider) do
    raise_error("No provider configuration available for #{provider}.")
  end

  @doc """
  Raise a ConfigError exception.
  """
  @spec raise_error(binary()) :: no_return
  def raise_error(message) do
    raise ConfigError, message: message
  end
end
