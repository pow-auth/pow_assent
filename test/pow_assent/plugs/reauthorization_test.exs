defmodule PowAssent.Plug.ReauthorizationTest do
  use ExUnit.Case
  doctest PowAssent.Plug.Reauthorization

  alias Plug.{Conn, Test}
  alias PowAssent.{Plug, Plug.Reauthorization}
  alias Pow.Config.ConfigError
  alias Pow.Plug, as: PowPlug
  alias Pow.Plug.Session, as: PowSession
  alias PowAssent.Test.{Ecto.Users.User, RepoMock}

  defmodule ReauthorizationPlugHandler do
    def reauthorize?(%{private: %{reauthorize?: true}}, _config), do: true
    def reauthorize?(_conn, _config), do: false

    def reauthorize(conn, provider, _config) do
      conn
      |> Conn.put_private(:reauthorizing, provider)
      |> Conn.halt()
    end
  end

  @cookie_key "reauthorization_provider"
  @default_config [
    plug: PowSession,
    user: User,
    repo: RepoMock,
    pow_assent: [
      providers: [
        test_provider: []
      ]
    ]
  ]
  @plug_opts [
    handler: ReauthorizationPlugHandler
  ]

  setup do
    conn =
      :get
      |> Test.conn("/")
      |> Conn.fetch_cookies()
      |> PowPlug.put_config(@default_config)

    {:ok, %{conn: conn}}
  end

  test "init/1 requires handler", %{conn: conn} do
    assert_raise ConfigError, "No :handler configuration option provided. It's required to set this when using PowAssent.Plug.Reauthorization.", fn ->
      init_plug(conn, Keyword.delete(@plug_opts, :handler))
    end
  end

  describe "call/2" do
    test "when in reauthorization condition with no cookie set", %{conn: conn} do
      conn =
        conn
        |> with_reauthorization_condition()
        |> init_plug(@plug_opts)

      refute conn.halted
    end

    test "when not in reauthorization condition with cookie set", %{conn: conn} do
      conn =
        conn
        |> with_reauthorization_cookie()
        |> init_plug(@plug_opts)

      refute conn.halted
    end

    test "when in reauthorization condition with cookie set with invalid provider", %{conn: conn} do
      conn =
        conn
        |> with_reauthorization_condition()
        |> with_reauthorization_cookie("invalid")
        |> init_plug(@plug_opts)

      refute conn.halted
      assert conn.resp_cookies == %{}
    end

    test "when in reauthorization condition with cookie set", %{conn: conn} do
      conn =
        conn
        |> with_reauthorization_condition()
        |> with_reauthorization_cookie()
        |> init_plug(@plug_opts)

      assert conn.halted
      assert conn.private.reauthorizing == "test_provider"
      assert cookie = conn.resp_cookies[@cookie_key]
      assert cookie.value == ""
      assert cookie.max_age == -1
    end

    test "when in reauthorization condition with cookie set with prepended `:otp_app`", %{conn: conn} do
      conn =
        conn
        |> PowPlug.put_config(@default_config ++ [otp_app: :test_app])
        |> with_reauthorization_condition()
        |> with_reauthorization_cookie("test_provider", "test_app_#{@cookie_key}")
        |> init_plug(@plug_opts)

      assert conn.halted
      assert conn.private.reauthorizing == "test_provider"
      assert cookie = conn.resp_cookies["test_app_#{@cookie_key}"]
      assert cookie.value == ""
      assert cookie.max_age == -1
    end
  end

  describe "call/2 when session is created" do
    test "writes cookie", %{conn: conn} do
      conn = init_plug(conn)

      refute conn.halted
      assert [_] = conn.private[:pow_assent_create_session_callbacks]

      conn = run_callback(conn)

      assert cookie = conn.resp_cookies[@cookie_key]
      assert cookie.value == "test_provider"
      assert cookie.max_age == 60 * 60 * 24 * 30
      assert cookie.path == "/"
    end

    test "writes cookie with prepended `:otp_app`", %{conn: conn} do
      conn =
        conn
        |> PowPlug.put_config(@default_config ++ [otp_app: :test_app])
        |> init_plug()
        |> run_callback()

      assert cookie = conn.resp_cookies["test_app_#{@cookie_key}"]
      assert cookie.value == "test_provider"
    end
  end

  defp with_reauthorization_condition(conn), do: Conn.put_private(conn, :reauthorize?, true)

  defp with_reauthorization_cookie(conn, provider \\ "test_provider", key \\ @cookie_key) do
    cookies = Map.new([{key, provider}])

    %{conn | cookies: cookies}
  end

  defp run_callback(conn) do
    assert {:ok, conn} = Plug.authenticate(conn, %{"provider" => "test_provider", "uid" => "existing_user"})

    Conn.send_resp(conn, 200, "")
  end

  defp init_plug(conn, config \\ @plug_opts) do
    Reauthorization.call(conn, Reauthorization.init(config))
  end
end
