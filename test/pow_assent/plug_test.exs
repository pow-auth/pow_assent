defmodule PowAssent.PlugTest do
  use ExUnit.Case
  doctest PowAssent.Plug

  alias Plug.{Conn, ProcessStore, Session}
  alias PowAssent.Plug
  alias PowAssent.Test.{UserIdentitiesMock, Ecto.Users.User}

  import PowAssent.Test.TestProvider, only: [expect_oauth2_flow: 2, put_oauth2_env: 1, put_oauth2_env: 2]

  @default_config [
    plug: Pow.Plug.Session,
    user: User,
    otp_app: :pow_assent,
    pow_assent: [
      user_identities_context: UserIdentitiesMock
    ]
  ]

  setup do
    conn =
      %Conn{}
      |> Pow.Plug.put_config(@default_config)
      |> init_session()

    {:ok, conn: conn}
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
      conn   = init_session(conn)

      put_oauth2_env(bypass)

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
      assert user_params == %{"name" => "Dan Schultzer"}
    end

    test "returns user params with preferred username as username", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{preferred_username: "john.doe"})

      assert {:ok, user_identity_params, user_params, _conn} = Plug.callback(conn, "test_provider", %{"code" => "access_token"}, "https://example.com/")
      assert user_identity_params == %{"provider" => "test_provider", "uid" => "new_user", "token" => %{"access_token" => "access_token"}}
      assert user_params == %{"username" => "john.doe", "name" => "Dan Schultzer"}
    end
  end

  test "authenticate/3", %{conn: conn} do
    {:error, conn} = Plug.authenticate(conn, %{"provider" => "test_provider", "uid" => "new_user"})

    {:ok, conn} = Plug.authenticate(conn, %{"provider" => "test_provider", "uid" => "existing_user"})

    assert Pow.Plug.current_user(conn) == UserIdentitiesMock.user()
    assert_pow_session conn
  end

  describe "upsert_identity/3" do
    setup %{conn: conn} do
      conn = Pow.Plug.assign_current_user(conn, %User{}, @default_config)

      {:ok, conn: conn}
    end

    test "creates user identity", %{conn: conn} do
      {:ok, user_identity, conn} = Plug.upsert_identity(conn, %{"provider" => "test_provider", "uid" => "new_identity"})

      assert user_identity.id == :new_identity
      assert_pow_session conn
    end

    test "updates user identity", %{conn: conn} do
      {:ok, user_identity, conn} = Plug.upsert_identity(conn, %{"provider" => "test_provider", "uid" => "existing_user_with_access_token"})

      assert user_identity.id == :existing_identity
      assert_pow_session conn
    end

    test "with identity already taken", %{conn: conn} do
      assert {:error, {:bound_to_different_user, _changeset}, conn} = Plug.upsert_identity(conn, %{"provider" => "test_provider", "uid" => "identity_taken"})

      assert Pow.Plug.current_user(conn) == %User{}
      refute_pow_session conn
    end
  end

  describe "create_user/3" do
    test "creates user", %{conn: conn} do
      {:ok, user, conn} = Plug.create_user(conn, %{"provider" => "test_provider", "uid" => "new_user"}, %{"email" => "test@example.com"})

      assert user.id == :new_user
      assert_pow_session conn
    end

    test "with missing user id", %{conn: conn} do
      assert {:error, {:invalid_user_id_field, _changeset}, conn} = Plug.create_user(conn, %{"provider" => "test_provider", "uid" => "new_user"}, %{"email" => ""})
      refute_pow_session conn
    end

    test "with identity already taken", %{conn: conn} do
      assert {:error, {:bound_to_different_user, _changeset}, conn} = Plug.create_user(conn, %{"provider" => "test_provider", "uid" => "identity_taken"}, %{})
      refute_pow_session conn
    end
  end

  describe "delete_identity/3" do
    test "deletes", %{conn: conn} do
      conn = Pow.Plug.assign_current_user(conn, %User{}, @default_config)

      assert {:ok, {1, nil}, _conn} = Plug.delete_identity(conn, "test_provider")
    end

    test "with error", %{conn: conn} do
      conn = Pow.Plug.assign_current_user(conn, :error, @default_config)

      assert {:error, :error, _conn} = Plug.delete_identity(conn, "test_provider")
    end
  end

  describe "providers_for_current_user/1" do
    test "lists providers for user", %{conn: conn} do
      conn = Pow.Plug.assign_current_user(conn, UserIdentitiesMock.user(), @default_config)

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

    test "with no provider configuration", %{conn: conn} do
      conn = Pow.Plug.put_config(conn, otp_app: :my_app)

      assert Plug.available_providers(conn) == []
    end
  end

  defp assert_pow_session(conn) do
    assert conn.private[:plug_session]["pow_assent_auth"]
  end
  defp refute_pow_session(conn) do
    refute conn.private[:plug_session]["pow_assent_auth"]
  end

  defp init_session(conn) do
    opts = Session.init(store: ProcessStore, key: "foobar")
    Session.call(conn, opts)
  end
end
