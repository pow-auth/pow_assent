defmodule PowAssent.Plug do
  @moduledoc """
  Plug helper methods.

  If you wish to configure PowAssent through the Pow plug interface rather than
  environment config, please add PowAssent config with `:pow_assent` config:

      plug Pow.Plug.Session,
        repo: MyApp.Repo,
        user: MyApp.User,
        pow_assent: [
          http_adapter: PowAssent.HTTPAdapter.Mint,
          json_library: Poison,
          user_identities_context: MyApp.UserIdentities
        ]
  """
  alias Plug.Conn
  alias PowAssent.{Config, Operations}

  @doc """
  Calls the authorize_url method for the provider strategy.

  A generated authorization URL will be returned. If `:state` is returned from
  the provider, it'll be added to the connection as private key
  `:pow_assent_state`.
  """
  @spec authorize_url(Conn.t(), binary(), binary()) :: {:ok, binary(), Conn.t()} | {:error. any(), Conn.t()}
  def authorize_url(conn, provider, redirect_uri) do
    {strategy, provider_config} = get_provider_config(conn, provider)

    provider_config
    |> Config.put(:redirect_uri, redirect_uri)
    |> strategy.authorize_url()
    |> maybe_put_state(conn)
  end

  defp maybe_put_state({:ok, %{url: url, state: state}}, conn) do
    {:ok, url, Plug.Conn.put_private(conn, :pow_assent_state, state)}
  end
  defp maybe_put_state({:ok, %{url: url}}, conn), do: {:ok, url, conn}
  defp maybe_put_state({:error, error}, conn), do: {:error, error, conn}

  @doc """
  Calls the callback method for the provider strategy.

  Returns the user params fetched from the provider.

  `:state` will be added to the provider config if `:pow_assent_state` is
  present as a private key in the connection.
  """
  @spec callback(Conn.t(), binary(), map(), binary()) :: {:ok, map(), Conn.t()} | {:error, any(), Conn.t()}
  def callback(conn, provider, params, redirect_uri) do
    {strategy, provider_config} = get_provider_config(conn, provider)
    params                      = Map.put(params, "redirect_uri", redirect_uri)

    provider_config
    |> maybe_set_state_config(conn)
    |> strategy.callback(params)
    |> case do
      {:ok, %{user: user}} -> {:ok, user, conn}
      {:error, error}      -> {:error, error, conn}
    end
  end

  defp maybe_set_state_config(config, %{private: %{pow_assent_state: state}}), do: Config.put(config, :state, state)
  defp maybe_set_state_config(config, _conn), do: config

  @doc """
  Authenticates a user with provider and provider user params.

  If successful, a new session will be created.
  """
  @spec authenticate(Conn.t(), binary(), map()) :: {:ok, Conn.t()} | {:error, Conn.t()}
  def authenticate(conn, provider, user_params) do
    config = fetch_config(conn)

    provider
    |> Operations.get_user_by_provider_uid(user_params["uid"], config)
    |> case do
      nil  -> {:error, conn}
      user -> {:ok, get_mod(config).do_create(conn, user, config)}
    end
  end

  @doc """
  Creates an identity for a user with provider and provider user params.

  If successful, a new session will be created.
  """
  @spec create_identity(Conn.t(), binary(), map()) :: {:ok, map(), Conn.t()} | {:error, {:bound_to_different_user, map()} | map(), Conn.t()}
  def create_identity(conn, provider, user_params) do
    config = fetch_config(conn)
    user   = Pow.Plug.current_user(conn)

    user
    |> Operations.create(provider, user_params["uid"], config)
    |> case do
      {:ok, user_identity} -> {:ok, user_identity, get_mod(config).do_create(conn, user, config)}
      {:error, error}      -> {:error, error, conn}
    end
  end

  @doc """
  Create a user with the provider and provider user params.

  If successful, a new session will be created.
  """
  @spec create_user(Conn.t(), binary(), map(), map() | nil) :: {:ok, map(), Conn.t()} | {:error, {:bound_to_different_user | :invalid_user_id_field, map()} | map(), Conn.t()}
  def create_user(conn, provider, user_params, user_id_params \\ nil) do
    config = fetch_config(conn)

    provider
    |> Operations.create_user(user_params["uid"], user_params, user_id_params, config)
    |> case do
      {:ok, user}     -> {:ok, user, get_mod(config).do_create(conn, user, config)}
      {:error, error} -> {:error, error, conn}
    end
  end

  @doc """
  Deletes the associated user identity for the current user and provider.
  """
  @spec delete_identity(Conn.t(), binary()) :: {:ok, map(), Conn.t()} | {:error, {:no_password, map()}, Conn.t()}
  def delete_identity(conn, provider) do
    config = fetch_config(conn)

    conn
    |> Pow.Plug.current_user()
    |> Operations.delete(provider, config)
    |> case do
      {:ok, results}  -> {:ok, results, conn}
      {:error, error} -> {:error, error, conn}
    end
  end

  @doc """
  Lists associated providers for the user.
  """
  @spec providers_for_current_user(Conn.t()) :: [atom()]
  def providers_for_current_user(conn) do
    config = fetch_config(conn)

    conn
    |> Pow.Plug.current_user()
    |> get_all_providers_for_user(config)
    |> Enum.map(&String.to_atom(&1.provider))
  end

  defp get_all_providers_for_user(nil, _config), do: []
  defp get_all_providers_for_user(user, config), do: Operations.all(user, config)

  @doc """
  Lists available providers for connection.
  """
  @spec available_providers(Conn.t() | Config.t()) :: [atom()]
  def available_providers(%Conn{} = conn) do
    conn
    |> fetch_config()
    |> available_providers()
  end
  def available_providers(config) do
    config
    |> Config.get_providers()
    |> Keyword.keys()
  end

  defp fetch_config(conn) do
    config = Pow.Plug.fetch_config(conn)

    config
    |> Keyword.take([:otp_app, :mod, :repo, :user])
    |> Keyword.merge(Keyword.get(config, :pow_assent, []))
  end

  defp get_provider_config(%Conn{} = conn, provider) do
    conn
    |> fetch_config()
    |> get_provider_config(provider)
  end
  defp get_provider_config(config, provider) do
    provider        = String.to_atom(provider)
    config          = Config.get_provider_config(config, provider)
    strategy        = config[:strategy]
    provider_config = Keyword.delete(config, :strategy)

    {strategy, provider_config}
  end

  defp get_mod(config), do: config[:mod]
end
