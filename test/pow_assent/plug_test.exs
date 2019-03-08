defmodule PowAssent.PlugTest do
  use ExUnit.Case
  doctest PowAssent.Plug

  alias Plug.{Conn, ProcessStore, Session}
  alias PowAssent.Plug
  alias PowAssent.Test.{UserIdentitiesMock, Ecto.Users.User}

  import PowAssent.Test.TestProvider, only: [expect_oauth2_flow: 2, put_oauth2_env: 1]

  @default_config [
    mod: Pow.Plug.Session,
    user: User,
    otp_app: :pow_assent,
    pow_assent: [
      user_identities_context: UserIdentitiesMock
    ]
  ]

  setup do
    conn = Pow.Plug.put_config(%Conn{}, @default_config)

    {:ok, conn: conn}
  end

  describe "authenticate/3" do
    test "returns redirect url and sets state", %{conn: conn} do
      put_oauth2_env(%Bypass{port: 8888})

      assert {:ok, url, conn} = Plug.authenticate(conn, "test_provider", "https://example.com/")

      assert url =~ "http://localhost:8888/oauth/authorize?client_id=client_id&redirect_uri=https%3A%2F%2Fexample.com%2F&response_type=code&state="
      assert Map.has_key?(conn.private, :pow_assent_state)
    end
  end

  @callback_params %{"code" => "access_token", "redirect_uri" => ""}

  describe "callback/3" do
    setup %{conn: conn} do
      bypass = Bypass.open()
      conn   = init_session(conn)

      put_oauth2_env(bypass)

      {:ok, conn: conn, bypass: bypass}
    end

    test "signs in user", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{uid: "existing_user"})

      {:ok, user, conn} = Plug.callback(conn, "test_provider", @callback_params)

      refute Map.has_key?(conn.private, :pow_assent_params)
      assert Pow.Plug.current_user(conn) == user
      assert_pow_session conn
    end

    test "with current assigned user creates user identity", %{conn: conn, bypass: bypass} do
      assigned_user = %{UserIdentitiesMock.user() | id: :loaded}
      conn          = Pow.Plug.assign_current_user(conn, assigned_user, @default_config)

      expect_oauth2_flow(bypass, user: %{uid: "new_identity"})

      {:ok, user, conn} = Plug.callback(conn, "test_provider", @callback_params)

      assert user == assigned_user
      refute Map.has_key?(conn.private, :pow_assent_params)
      refute_pow_session conn
    end

    test "with current assigned user and identity bound to other user", %{conn: conn, bypass: bypass} do
      assigned_user = %{UserIdentitiesMock.user() | id: :bound_to_different_user}
      conn          = Pow.Plug.assign_current_user(conn, assigned_user, @default_config)

      expect_oauth2_flow(bypass, user: %{uid: "new_identity"})

      {:error, {:bound_to_different_user, _changeset}, conn} = Plug.callback(conn, "test_provider", @callback_params)

      refute Map.has_key?(conn.private, :pow_assent_params)
      refute_pow_session conn
    end

    test "creates user", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{uid: "new_user"})

      {:ok, {:new, user}, conn} = Plug.callback(conn, "test_provider", @callback_params)

      assert Pow.Plug.current_user(conn) == user
      assert_pow_session conn
    end

    test "missing user id", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{uid: "new_user", email: ""})

      {:error, {:invalid_user_id_field, _changeset}, conn} = Plug.callback(conn, "test_provider", @callback_params)

      assert Map.has_key?(conn.private, :pow_assent_params)
      refute_pow_session conn
    end
  end

  describe "create_user/4" do
    setup %{conn: conn} do
      conn = init_session(conn)

      {:ok, conn: conn}
    end

    test "creates user", %{conn: conn} do
      assert {:ok, {:new, user}, conn} = Plug.create_user(conn, "test_provider", %{"uid" => "new_user"}, %{"email" => "test@example.com"})

      assert Pow.Plug.current_user(conn) == user
      assert_pow_session conn
    end

    test "identity bound to other user", %{conn: conn} do
      {:error, {:bound_to_different_user, _changeset}, conn} = Plug.create_user(conn, "test_provider", %{"uid" => "different_user"}, %{})

      refute_pow_session conn
    end
  end

  describe "delete_identity/3" do
    setup %{conn: conn} do
      user = UserIdentitiesMock.user()
      conn =
        conn
        |> init_session()
        |> Pow.Plug.assign_current_user(user, @default_config)

      {:ok, conn: conn, user: user}
    end

    test "deletes", %{conn: conn} do
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
