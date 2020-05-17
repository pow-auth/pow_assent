defmodule PowAssent.PlugTest do
  use ExUnit.Case
  doctest PowAssent.Plug

  alias Plug.{Conn, ProcessStore, Session, Test}
  alias Pow.Plug.Session, as: PowSession
  alias PowAssent.Plug
  alias PowAssent.Test.{Ecto.UserIdentities.UserIdentity, Ecto.Users.User, EtsCacheMock, RepoMock}

  import PowAssent.Test.TestProvider, only: [expect_oauth2_flow: 2, put_oauth2_env: 1, put_oauth2_env: 2]

  @default_config [
    plug: PowSession,
    user: User,
    otp_app: :pow_assent,
    repo: RepoMock,
    cache_store_backend: EtsCacheMock
  ]

  setup do
    EtsCacheMock.init()

    {:ok, conn: init_session_conn()}
  end

  describe "authorize_url/3" do
    test "generates state", %{conn: conn} do
      put_oauth2_env(%Bypass{port: 8888})

      assert {:ok, url, conn} = Plug.authorize_url(conn, "test_provider", "https://example.com/")

      assert %{private: %{pow_assent_session_params: %{state: state}}} = conn
      assert url == "http://localhost:8888/oauth/authorize?client_id=client_id&redirect_uri=https%3A%2F%2Fexample.com%2F&response_type=code&state=#{state}"
    end

    test "uses nonce from config", %{conn: conn} do
      put_oauth2_env(%Bypass{port: 8888}, nonce: "nonce", strategy: Assent.Strategy.OIDC, openid_configuration: %{"authorization_endpoint" => "http://localhost:8888/oauth/authorize"})

      assert {:ok, url, conn} = Plug.authorize_url(conn, "test_provider", "https://example.com/")

      assert %{private: %{pow_assent_session_params: %{state: state, nonce: nonce}}} = conn
      assert nonce == "nonce"
      assert url == "http://localhost:8888/oauth/authorize?client_id=client_id&nonce=nonce&redirect_uri=https%3A%2F%2Fexample.com%2F&response_type=code&scope=openid&state=#{state}"
    end

    test "uses generated nonce when nonce in config set to true", %{conn: conn} do
      put_oauth2_env(%Bypass{port: 8888}, nonce: true, strategy: Assent.Strategy.OIDC, openid_configuration: %{"authorization_endpoint" => "http://localhost:8888/oauth/authorize"})

      assert {:ok, url, conn} = Plug.authorize_url(conn, "test_provider", "https://example.com/")
      assert %{private: %{pow_assent_session_params: %{state: state, nonce: nonce}}} = conn
      assert url == "http://localhost:8888/oauth/authorize?client_id=client_id&#{URI.encode_query(%{nonce: nonce})}&redirect_uri=https%3A%2F%2Fexample.com%2F&response_type=code&scope=openid&state=#{state}"
    end
  end

  describe "callback/3" do
    setup %{conn: conn} do
      bypass = Bypass.open()

      put_oauth2_env(bypass)

      conn = Conn.put_private(conn, :pow_assent_session_params, %{})

      {:ok, conn: conn, bypass: bypass}
    end

    test "returns user params", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, access_token_assert_fn: fn conn ->
        {:ok, body, _conn} = Conn.read_body(conn, [])
        params = URI.decode_query(body)

        assert params["redirect_uri"] == "https://example.com/"
      end)

      assert {:ok, user_identity_params, user_params, _conn} = Plug.callback(conn, "test_provider", %{"code" => "access_token"}, "https://example.com/")
      assert user_identity_params == %{"provider" => "test_provider", "uid" => "new_user", "token" => %{"access_token" => "access_token"}}
      assert user_params == %{"name" => "John Doe", "email" => "test@example.com"}
    end

    test "returns user params with preferred username as username", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{preferred_username: "john.doe"})

      assert {:ok, user_identity_params, user_params, _conn} = Plug.callback(conn, "test_provider", %{"code" => "access_token"}, "https://example.com/")
      assert user_identity_params == %{"provider" => "test_provider", "uid" => "new_user", "token" => %{"access_token" => "access_token"}}
      assert user_params == %{"username" => "john.doe", "name" => "John Doe", "email" => "test@example.com"}
    end
  end

  test "authenticate/3", %{conn: conn} do
    assert {:error, _conn} = Plug.authenticate(conn, %{"provider" => "test_provider", "uid" => "new_user"})
    refute Pow.Plug.current_user(conn)
    refute fetch_session_id(conn)

    assert {:ok, conn} = Plug.authenticate(conn, %{"provider" => "test_provider", "uid" => "existing_user"})
    assert Pow.Plug.current_user(conn) == %User{id: 1, email: "test@example.com"}
    assert fetch_session_id(conn)
  end

  describe "upsert_identity/3" do
    @user %User{id: 1}

    setup %{conn: conn} do
      conn = Pow.Plug.assign_current_user(conn, @user, @default_config)

      {:ok, conn: conn}
    end

    test "creates user identity", %{conn: conn} do
      assert {:ok, user_identity, conn} = Plug.upsert_identity(conn, %{"provider" => "test_provider", "uid" => "new_identity"})

      assert user_identity.id == :inserted
      assert fetch_session_id(conn)
    end

    test "updates user identity", %{conn: conn} do
      assert {:ok, user_identity, conn} = Plug.upsert_identity(conn, %{"provider" => "test_provider", "uid" => "existing_user"})

      assert user_identity.id == :updated

      assert fetch_session_id(conn)
    end

    test "with identity already taken", %{conn: conn} do
      assert {:error, {:bound_to_different_user, _changeset}, conn} = Plug.upsert_identity(conn, %{"provider" => "test_provider", "uid" => "identity_taken"})

      assert Pow.Plug.current_user(conn) == @user
      refute fetch_session_id(conn)
    end
  end

  describe "create_user/3" do
    @user_identity_attrs %{"provider" => "test_provider", "uid" => "new_user"}
    @user_attrs          %{"name" => "John Doe", "email" => "test@example.com"}

    test "creates user", %{conn: conn} do
      assert {:ok, user, conn} = Plug.create_user(conn, @user_identity_attrs, @user_attrs)

      assert user.id == :inserted
      assert fetch_session_id(conn)
    end

    test "with missing user id", %{conn: conn} do
      assert {:error, {:invalid_user_id_field, _changeset}, conn} = Plug.create_user(conn, @user_identity_attrs, Map.delete(@user_attrs, "email"))
      refute fetch_session_id(conn)
    end

    test "with identity already taken", %{conn: conn} do
      assert {:error, {:bound_to_different_user, _changeset}, conn} = Plug.create_user(conn, Map.put(@user_identity_attrs, "uid", "identity_taken"), @user_attrs)
      refute fetch_session_id(conn)
    end
  end

  describe "delete_identity/3" do
    @user %User{id: 1, password_hash: "", user_identities: [%UserIdentity{id: 1, provider: "test_provider"}, %UserIdentity{id: 2, provider: "other_provider"}]}

    test "deletes", %{conn: conn} do
      conn = Pow.Plug.assign_current_user(conn, @user, @default_config)

      assert {:ok, {1, nil}, _conn} = Plug.delete_identity(conn, "test_provider")
    end

    test "with error", %{conn: conn} do
      conn = Pow.Plug.assign_current_user(conn, Map.put(@user, :password_hash, nil), @default_config)

      assert {:error, {:no_password, _changeset}, _conn} = Plug.delete_identity(conn, "test_provider")
    end
  end

  describe "providers_for_current_user/1" do
    @user %User{id: 1}

    test "lists providers for user", %{conn: conn} do
      conn = Pow.Plug.assign_current_user(conn, @user, @default_config)

      assert Plug.providers_for_current_user(conn) == [:test_provider]
    end

    test "without assigned user returns empty list", %{conn: conn} do
      assert Plug.providers_for_current_user(conn) == []
    end
  end

  describe "available_providers/1" do
    test "lists providers", %{conn: conn} do
      put_oauth2_env(%Bypass{port: 8888})

      assert Plug.available_providers(conn) == [:test_provider]
    end

    test "with no provider configuration" do
      conn = conn(otp_app: :my_app)

      assert Plug.available_providers(conn) == []
    end
  end

  describe "init_session/1" do
    @store_config [namespace: "pow_assent_sessions"]

    test "initializes new session", %{conn: conn} do
      init_conn = Plug.init_session(conn)

      assert init_conn.private[:pow_assent_session] == %{}
    end

    test "stores session if not empty and pow_assent_session_info: :write", %{conn: init_conn} do
      conn =
        init_conn
        |> Plug.init_session()
        |> Conn.put_private(:pow_assent_session_info, :write)
        |> Conn.send_resp(200, "")

      assert conn.private[:plug_session] == %{}
      refute_received {:ets, :put, _any, _config}

      conn =
        init_conn
        |> Plug.init_session()
        |> Conn.put_private(:pow_assent_session, %{a: 1})
        |> Conn.send_resp(200, "")

      assert conn.private[:plug_session] == %{}
      refute_received {:ets, :put, _any, _config}

      conn =
        init_conn
        |> Plug.init_session()
        |> Conn.put_private(:pow_assent_session, %{a: 1})
        |> Conn.put_private(:pow_assent_session_info, :write)
        |> Conn.send_resp(200, "")

      assert key = conn.private[:plug_session]["pow_assent_session"]
      assert EtsCacheMock.get(@store_config, key) == %{a: 1}
    end

    test "initializes existing session", %{conn: conn} do
      key = "test"

      EtsCacheMock.put(@store_config, [{key, %{a: 1}}])

      conn =
        conn
        |> Conn.put_session(:pow_assent_session, key)
        |> Conn.send_resp(200, "")
        |> recycle_session_conn()
        |> init_session_conn()
        |> Plug.init_session()
        |> Conn.send_resp(200, "")

      refute conn.private[:plug_session]["pow_assent_session"]
      assert conn.private[:pow_assent_session] == %{a: 1}
      assert EtsCacheMock.get(@store_config, key) == :not_found
    end
  end

  test "put_session/3", %{conn: conn} do
    conn =
      conn
      |> Plug.init_session()
      |> Plug.put_session(:a, 1)
      |> Plug.put_session(:b, 2)

    assert conn.private[:pow_assent_session] == %{a: 1, b: 2}
    assert conn.private[:pow_assent_session_info] == :write
  end

  defp init_session_conn(conn \\ nil) do
    (conn || conn(@default_config))
    |> Session.call(Session.init(store: ProcessStore, key: "foobar"))
    |> PowSession.call(PowSession.init(@default_config))
  end

  defp conn(config) do
    :get
    |> Test.conn("/")
    |> Conn.put_private(:pow_config, config)
  end

  defp recycle_session_conn(old_conn) do
    []
    |> conn()
    |> Test.recycle_cookies(old_conn)
    |> init_session_conn()
  end

  defp fetch_session_id(conn) do
    conn =
      conn
      |> Map.put(:secret_key_base, String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2))
      |> Conn.send_resp(200, "")

    Map.get(conn.private[:plug_session], "pow_assent_auth")
  end
end
