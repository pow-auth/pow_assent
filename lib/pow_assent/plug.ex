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
  alias Pow.Plug

  @doc """
  Calls the authorize_url method for the provider strategy.

  A generated authorization URL will be returned. If `:session_params` is
  returned from the provider, it'll be added to the connection as private key
  `:pow_assent_session_params`.

  If `:nonce` is set to `true` in the PowAssent provider configuration, a
  randomly generated nonce will be added to the provider configuration.
  """
  @spec authorize_url(Conn.t(), binary(), binary()) :: {:ok, binary(), Conn.t()} | {:error, any(), Conn.t()}
  def authorize_url(conn, provider, redirect_uri) do
    {strategy, provider_config} = get_provider_config(conn, provider, redirect_uri)

    provider_config
    |> maybe_gen_nonce()
    |> strategy.authorize_url()
    |> maybe_put_session_params(conn)
  end

  defp maybe_gen_nonce(config) do
    case Config.get(config, :nonce, nil) do
      true -> Config.put(config, :nonce, gen_nonce())
      _any -> config
    end
  end

  defp gen_nonce() do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode64(padding: false)
  end

  defp maybe_put_session_params({:ok, %{url: url, session_params: params}}, conn) do
    {:ok, url, Conn.put_private(conn, :pow_assent_session_params, params)}
  end
  defp maybe_put_session_params({:ok, %{url: url}}, conn), do: {:ok, url, conn}
  defp maybe_put_session_params({:error, error}, conn), do: {:error, error, conn}

  @doc """
  Calls the callback method for the provider strategy and will authenticate,
  upsert user identity, or create user.

  See `callback/4`, `authenticate/2`, `upsert_identity/2`, and `create_user/4`
  for more.

  To track the state of the flow the following keys may be populated in
  `conn.private`:

    - `:pow_assent_callback_state` - The state of the flow, that is either
      `{:ok, step}` or `{:error, step}`.
    - `:pow_assent_callback_params` - The params returned by the strategy
      callback phase.
    - `:pow_assent_callback_error` - The resulting error of any step.

  The value of `:pow_assent_callback_state` may be one of the following:

  - `{:error, :strategy}` - An error ocurred during strategy callback
      phase. `:pow_assent_callback_error` will be populated with the error.
  - `{:ok, :upsert_user_identity}` - User identity was created or updated.
  - `{:error, :upsert_user_identity}` - User identity could not be created
    or updated. `:pow_assent_callback_error` will be populated with the
    changeset.
  - `{:ok, :create_user}` - User was created.
  - `{:error, :create_user}` - User could not be created.
    `:pow_assent_callback_error` will be populated with the changeset.

  If `:pow_assent_registration` in `conn.private` is set to `false` then
  `create_user/4` will not be called and the `:pow_assent_callback_state` set
  to `{:error, :create_user}` with `nil` value for
  `:pow_assent_callback_error`.
  """
  @spec callback_upsert(Conn.t(), binary(), map(), binary()) :: {:ok, Conn.t()} | {:error, Conn.t()}
  def callback_upsert(conn, provider, params, redirect_uri) do
    conn
    |> callback(provider, params, redirect_uri)
    |> handle_callback()
    |> maybe_authenticate()
    |> maybe_upsert_user_identity()
    |> maybe_create_user()
    |> case do
      %{private: %{pow_assent_callback_state: {:ok, _method}}} = conn ->
        {:ok, conn}

      conn ->
        {:error, conn}
    end
  end

  defp handle_callback({:ok, user_identity_params, user_params, conn}) do
    conn
    |> Conn.put_private(:pow_assent_callback_state, {:ok, :strategy})
    |> Conn.put_private(:pow_assent_callback_params, %{user_identity: user_identity_params, user: user_params})
  end
  defp handle_callback({:error, error, conn})  do
    conn
    |> Conn.put_private(:pow_assent_callback_state, {:error, :strategy})
    |> Conn.put_private(:pow_assent_callback_error, error)
  end

  defp maybe_authenticate(%{private: %{pow_assent_callback_state: {:ok, :strategy}, pow_assent_callback_params: params}} = conn) do
    user_identity_params = Map.fetch!(params, :user_identity)

    case Pow.Plug.current_user(conn) do
      nil ->
        conn
        |> authenticate(user_identity_params)
        |> case do
          {:ok, conn}    -> conn
          {:error, conn} -> conn
        end

      _user ->
        conn
    end
  end
  defp maybe_authenticate(conn), do: conn

  defp maybe_upsert_user_identity(%{private: %{pow_assent_callback_state: {:ok, :strategy}, pow_assent_callback_params: params}} = conn) do
    user_identity_params = Map.fetch!(params, :user_identity)

    case Pow.Plug.current_user(conn) do
      nil ->
        conn

      _user ->
        conn
        |> upsert_identity(user_identity_params)
        |> case do
          {:ok, _user_identity, conn} ->
            Conn.put_private(conn, :pow_assent_callback_state, {:ok, :upsert_user_identity})

          {:error, changeset, conn} ->
            conn
            |> Conn.put_private(:pow_assent_callback_state, {:error, :upsert_user_identity})
            |> Conn.put_private(:pow_assent_callback_error, changeset)
        end
    end
  end
  defp maybe_upsert_user_identity(conn), do: conn

  defp maybe_create_user(%{private: %{pow_assent_registration: false}} = conn) do
    conn
    |> Conn.put_private(:pow_assent_callback_state, {:error, :create_user})
    |> Conn.put_private(:pow_assent_callback_error, nil)
  end
  defp maybe_create_user(%{private: %{pow_assent_callback_state: {:ok, :strategy}, pow_assent_callback_params: params}} = conn) do
    user_params          = Map.fetch!(params, :user)
    user_identity_params = Map.fetch!(params, :user_identity)

    case Pow.Plug.current_user(conn) do
      nil ->
        conn
        |> Conn.put_private(:pow_assent_callback_action, :create_user)
        |> create_user(user_identity_params, user_params)
        |> case do
          {:ok, _user, conn} ->
            Conn.put_private(conn, :pow_assent_callback_state, {:ok, :create_user})

          {:error, changeset, conn} ->
            conn
            |> Conn.put_private(:pow_assent_callback_state, {:error, :create_user})
            |> Conn.put_private(:pow_assent_callback_error, changeset)
        end

      _user ->
        conn
    end
  end
  defp maybe_create_user(conn), do: conn

  @doc """
  Calls the callback method for the provider strategy.

  Returns the user identity params and user params fetched from the provider.

  `:session_params` will be added to the provider config if
  `:pow_assent_session_params` is present as a private key in the connection.
  """
  @spec callback(Conn.t(), binary(), map(), binary()) :: {:ok, map(), map(), Conn.t()} | {:error, any(), Conn.t()}
  def callback(conn, provider, params, redirect_uri) do
    {strategy, provider_config} = get_provider_config(conn, provider, redirect_uri)

    provider_config
    |> maybe_set_session_params_config(conn)
    |> strategy.callback(params)
    |> parse_callback_response(provider, conn)
  end

  defp maybe_set_session_params_config(config, %{private: %{pow_assent_session_params: params}}), do: Config.put(config, :session_params, params)
  defp maybe_set_session_params_config(config, _conn), do: config

  defp parse_callback_response({:ok, %{user: user} = response}, provider, conn) do
    other_params = Map.drop(response, [:user])

    user
    |> normalize_username()
    |> split_user_identity_params()
    |> handle_user_identity_params(other_params, provider, conn)
  end
  defp parse_callback_response({:error, error}, _provider, conn), do: {:error, error, conn}

  defp normalize_username(%{"preferred_username" => username} = params) do
    params
    |> Map.delete("preferred_username")
    |> Map.put("username", username)
  end
  defp normalize_username(params), do: params

  defp split_user_identity_params(%{"sub" => uid} = params) do
    user_params = Map.delete(params, "sub")

    {%{"uid" => uid}, user_params}
  end

  defp handle_user_identity_params({user_identity_params, user_params}, other_params, provider, conn) do
    user_identity_params = Map.put(user_identity_params, "provider", provider)
    other_params         = for {key, value} <- other_params, into: %{}, do: {Atom.to_string(key), value}

    user_identity_params =
      user_identity_params
      |> Map.put("provider", provider)
      |> Map.merge(other_params)

    {:ok, user_identity_params, user_params, conn}
  end

  @doc """
  Authenticates a user with provider and provider user params.

  If successful, a new session will be created.
  """
  @spec authenticate(Conn.t(), map()) :: {:ok, Conn.t()} | {:error, Conn.t()}
  def authenticate(conn, %{"provider" => provider, "uid" => uid}) do
    config = fetch_config(conn)

    provider
    |> Operations.get_user_by_provider_uid(uid, config)
    |> case do
      nil  -> {:error, conn}
      user -> {:ok, Plug.get_plug(config).do_create(conn, user, config)}
    end
  end

  # TODO: Remove by 0.4.0
  @doc false
  @deprecated "Use `upsert_identity/2` instead"
  @spec create_identity(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, {:bound_to_different_user, map()} | map(), Conn.t()}
  def create_identity(conn, user_identity_params), do: upsert_identity(conn, user_identity_params)

  @doc """
  Will upsert identity for the current user.

  If successful, a new session will be created.
  """
  @spec upsert_identity(Conn.t(), map()) :: {:ok, map(), Conn.t()} | {:error, {:bound_to_different_user, map()} | map(), Conn.t()}
  def upsert_identity(conn, user_identity_params) do
    config = fetch_config(conn)
    user   = Plug.current_user(conn)

    user
    |> Operations.upsert(user_identity_params, config)
    |> case do
      {:ok, user_identity} -> {:ok, user_identity, Plug.get_plug(config).do_create(conn, user, config)}
      {:error, error}      -> {:error, error, conn}
    end
  end

  @doc """
  Create a user with the provider and provider user params.

  If successful, a new session will be created.
  """
  @spec create_user(Conn.t(), map(), map(), map() | nil) :: {:ok, map(), Conn.t()} | {:error, {:bound_to_different_user | :invalid_user_id_field, map()} | map(), Conn.t()}
  def create_user(conn, user_identity_params, user_params, user_id_params \\ nil) do
    config = fetch_config(conn)

    user_identity_params
    |> Operations.create_user(user_params, user_id_params, config)
    |> case do
      {:ok, user}     -> {:ok, user, Plug.get_plug(config).do_create(conn, user, config)}
      {:error, error} -> {:error, error, conn}
    end
  end

  @doc """
  Creates a changeset.
  """
  @spec change_user(Conn.t(), map()) :: map()
  def change_user(conn, params \\ %{}, user_params \\ %{}, user_id_params \\ %{}) do
    config = fetch_config(conn)

    Operations.user_identity_changeset(params, user_params, user_id_params, config)
  end

  @doc """
  Deletes the associated user identity for the current user and provider.
  """
  @spec delete_identity(Conn.t(), binary()) :: {:ok, map(), Conn.t()} | {:error, {:no_password, map()}, Conn.t()}
  def delete_identity(conn, provider) do
    config = fetch_config(conn)

    conn
    |> Plug.current_user()
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
    |> Plug.current_user()
    |> get_all_providers_for_user(config)
    |> Enum.map(&String.to_existing_atom(&1.provider))
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
    config = Plug.fetch_config(conn)

    config
    |> Keyword.take([:otp_app, :plug, :repo, :user])
    |> Keyword.merge(Keyword.get(config, :pow_assent, []))
  end

  defp get_provider_config(%Conn{} = conn, provider, redirect_uri) do
    conn
    |> fetch_config()
    |> get_provider_config(provider, redirect_uri)
  end
  defp get_provider_config(config, provider, redirect_uri) do
    config          = Config.get_provider_config(config, provider)
    strategy        = config[:strategy]
    provider_config =
      config
      |> Keyword.delete(:strategy)
      |> Config.put(:redirect_uri, redirect_uri)

    {strategy, provider_config}
  end

  @private_session_key :pow_assent_session

  @doc """
  Initializes session.
  """
  @spec init_session(Conn.t()) :: Conn.t()
  def init_session(conn) do
    session_key = Atom.to_string(@private_session_key)
    value =
      case Conn.get_session(conn) do
        %{^session_key => session} -> session
        _                          -> Map.get(conn.private, @private_session_key, %{})
      end

    conn
    |> Conn.put_private(@private_session_key, value)
    |> Conn.register_before_send(fn conn ->
      conn.private
      |> Map.get(@private_session_key)
      |> case do
        nil   -> conn
        value -> Conn.put_session(conn, session_key, value)
      end
    end)
  end

  @doc """
  Inserts value for key in session.
  """
  @spec put_session(Conn.t(), atom(), any()) :: Conn.t()
  def put_session(%{private: %{@private_session_key => session}} = conn, key, value) do
    session = Map.put(session, key, value)

    Conn.put_private(conn, @private_session_key, session)
  end

  @doc """
  Deletes key from session.
  """
  @spec delete_session(Conn.t(), atom()) :: Conn.t()
  def delete_session(%{private: %{@private_session_key => session}} = conn, key) do
    session = Map.delete(session, key)

    Conn.put_private(conn, @private_session_key, session)
  end
end
