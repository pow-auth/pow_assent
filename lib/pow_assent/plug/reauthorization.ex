defmodule PowAssent.Plug.Reauthorization do
  @moduledoc """
  This plug can reauthorize a user who signed in through a provider.

  The plug is dependent on a `:handler` that has the following methods:

   * `reauthorize?/2` - verifies the request for reauthorization condition. If
    the condition exists for the request (usually the sign in path), the
    reauthorization cookie will be fetched and deleted, the `reauthorize/2`
    callback will be called, and the connection halted.

  * `clear_reauthorization?/2` - verifies the request for clear reauthorization
    condition. If the condition exists (usually the session delete path) then
    the cookie is deleted.

  * `reauthorize/3` - the callback to handle the request when a reauthorization
    condition exists. Usually this would redirect the user.

  See `PowAssent.Phoenix.ReauthorizationPlugHandler` for a Phoenix example.

  ## Example

      plug PowAssent.Plug.Reauthorization,
        handler: MyApp.ReauthorizationHandler

  ## Configuration options

    * `:handler` - the handler module. Should either be a module or a tuple
      `{module, options}`.

    * `:reauthorization_cookie_key` - reauthorization key name. This defaults
      to "authorization_provider". If `:otp_app` is used it'll automatically
      prepend the key with the `:otp_app` value.

    * `:reauthorization_cookie_opts` - keyword list of cookie options, see
      `Plug.Conn.put_resp_cookie/4` for options. The default options are
      `[max_age: max_age, path: "/"]` where `:max_age` is 30 days.
  """
  alias Plug.Conn
  alias Pow.Config
  alias Pow.Plug, as: PowPlug
  alias PowAssent.Plug

  @cookie_key "reauthorization_provider"
  @cookie_max_age Integer.floor_div(:timer.hours(24) * 30, 1000)

  @doc false
  @spec init(Config.t()) :: {Config.t(), {module(), Config.t()}}
  def init(config) do
    handler = get_handler(config)
    config  = Keyword.delete(config, :handler)

    {config, handler}
  end

  defp get_handler(plug_config) do
    {handler, config} =
      plug_config
      |> Config.get(:handler)
      |> Kernel.||(raise_no_handler())
      |> case do
        {handler, config} -> {handler, config}
        handler           -> {handler, []}
      end

    {handler, Keyword.put(config, :reauthorization_plug, __MODULE__)}
  end

  @doc false
  @spec call(Conn.t(), {Config.t(), {module(), Config.t()}}) :: Conn.t()
  def call(conn, {config, {handler, handler_config}}) do
    config =
      conn
      |> Plug.fetch_config()
      |> Config.merge(config)

    conn =
      conn
      |> Conn.fetch_cookies()
      |> Plug.put_create_session_callback(&store_reauthorization_provider/3)

    provider = get_reauthorization_provider(conn, {handler, handler_config}, config)

    cond do
      provider ->
        conn
        |> clear_cookie(config)
        |> handler.reauthorize(provider, handler_config)
        |> Conn.halt()

      clear_reauthorization?(conn,  {handler, handler_config}) ->
        clear_cookie(conn, config)

      true ->
        conn
    end
  end

  defp store_reauthorization_provider(conn, provider, config) do
    Conn.register_before_send(conn, &Conn.put_resp_cookie(&1, cookie_key(config), provider, cookie_opts(config)))
  end

  defp cookie_key(config) do
    Config.get(config, :reauthorization_cookie_key, default_cookie_key(config))
  end

  defp default_cookie_key(config) do
    PowPlug.prepend_with_namespace(config, @cookie_key)
  end

  defp cookie_opts(config) do
    config
    |> Config.get(:reauthorization_cookie_opts, [])
    |> Keyword.put_new(:max_age, @cookie_max_age)
    |> Keyword.put_new(:path, "/")
  end

  defp get_reauthorization_provider(conn, {handler, handler_config}, config) do
    with :ok             <- check_should_reauthorize(conn, {handler, handler_config}),
         {:ok, provider} <- fetch_provider_from_cookie(conn, config) do
      provider
    else
      :error -> nil
    end
  end

  defp check_should_reauthorize(conn, {handler, handler_config}) do
    case handler.reauthorize?(conn, handler_config) do
      true  -> :ok
      false -> :error
    end
  end

  defp fetch_provider_from_cookie(conn, config) do
    case conn.cookies[cookie_key(config)] do
      nil ->
        :error

      provider ->
        config
        |> Plug.available_providers()
        |> Enum.any?(&Atom.to_string(&1) == provider)
        |> case do
          true  -> {:ok, provider}
          false -> :error
        end
    end
  end

  defp clear_cookie(conn, config) do
    Conn.put_resp_cookie(conn, cookie_key(config), "", max_age: -1)
  end

  defp clear_reauthorization?(conn, {handler, handler_config}),
    do: handler.clear_reauthorization?(conn, handler_config)

  @spec raise_no_handler :: no_return
  defp raise_no_handler do
    Config.raise_error("No :handler configuration option provided. It's required to set this when using #{inspect __MODULE__}.")
  end
end
