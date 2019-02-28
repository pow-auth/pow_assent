defmodule PowAssent.PlugTest do
  use ExUnit.Case
  doctest PowAssent.Plug

  alias Plug.{ProcessStore, Session, Test}
  alias PowAssent.Plug
  alias PowAssent.Test.{UserIdentitiesMock, Ecto.Users.User}
  import PowAssent.OAuthHelpers

  @default_config [
    mod: Pow.Plug.Session,
    user: User,
    otp_app: :pow_assent,
    pow_assent: [
      user_identities_context: UserIdentitiesMock
    ]
  ]

  defp setup_conn do
    conn = Test.conn(:get, "/")
    private = Map.put(conn.private, :pow_config, @default_config)

    %{conn | private: private}
  end

  describe "authenticate/3" do
    setup do
      server = Bypass.open()
      setup_oauth2_strategy_env(server)

      {:ok, conn: setup_conn(), server: server}
    end

    test "returns redirect url", %{conn: conn, server: server} do
      assert {:ok, url, _conn} = Plug.authenticate(conn, "test_provider", "https://example.com/")

      assert url =~ "#{bypass_server(server)}/oauth/authorize?client_id=client_id&redirect_uri=https%3A%2F%2Fexample.com%2F&response_type=code&state="
    end
  end

  describe "callback/3" do
    setup do
      server = Bypass.open()
      setup_oauth2_strategy_env(server)
      opts = Session.init(store: ProcessStore, key: "foobar")
      conn = Session.call(setup_conn(), opts)

      {:ok, conn: conn, server: server}
    end

    test "loads existing user", %{conn: conn, server: server} do
      expect_oauth2_flow(server, user: %{uid: "existing_user"})

      assert {:ok, url, _conn} = Plug.authenticate(conn, "test_provider", "https://example.com/")
      assert {:ok, %{id: 1, email: "test@example.com"}, _conn} = Plug.callback(conn, "test_provider", %{"code" => "access_token", "redirect_uri" => url})
    end

    test "creates user identity", %{conn: conn, server: server} do
      user = %{UserIdentitiesMock.user() | id: :loaded}
      conn = Pow.Plug.assign_current_user(conn, user, @default_config)

      expect_oauth2_flow(server, user: %{uid: "new_identity"})

      assert {:ok, url, _conn} = Plug.authenticate(conn, "test_provider", "https://example.com/")
      assert {:ok, ^user, conn} = Plug.callback(conn, "test_provider", %{"code" => "access_token", "redirect_uri" => url})
      refute conn.private[:plug_session]["pow_assent_auth"]
    end

    test "already taken user identity", %{conn: conn, server: server} do
      conn = Pow.Plug.assign_current_user(conn, %{UserIdentitiesMock.user() | id: :bound_to_different_user}, @default_config)

      expect_oauth2_flow(server, user: %{uid: "new_identity"})

      assert {:ok, url, _conn} = Plug.authenticate(conn, "test_provider", "https://example.com/")
      assert {:error, {:bound_to_different_user, %{}}, conn} = Plug.callback(conn, "test_provider", %{"code" => "access_token", "redirect_uri" => url})
      refute conn.private[:plug_session]["pow_assent_auth"]
    end

    test "creates user", %{conn: conn, server: server} do
      expect_oauth2_flow(server, user: %{uid: "new_user"})

      assert {:ok, url, _conn} = Plug.authenticate(conn, "test_provider", "https://example.com/")
      assert {:ok, {:new, %{id: :new_user, email: "test@example.com"}}, conn} = Plug.callback(conn, "test_provider", %{"code" => "access_token", "redirect_uri" => url})
      assert conn.private[:plug_session]["pow_assent_auth"]
    end

    test "missing user id", %{conn: conn, server: server} do
      expect_oauth2_flow(server, user: %{uid: "new_user", email: ""})

      assert {:ok, url, _conn} = Plug.authenticate(conn, "test_provider", "https://example.com/")
      assert {:error, {:invalid_user_id_field, %{}}, conn} = Plug.callback(conn, "test_provider", %{"code" => "access_token", "redirect_uri" => url})
      refute conn.private[:plug_session]["pow_assent_auth"]
    end
  end

  describe "create_user/4" do
    setup do
      opts = Session.init(store: ProcessStore, key: "foobar")
      conn = Session.call(setup_conn(), opts)

      {:ok, conn: conn}
    end

    test "creates user", %{conn: conn} do
      assert {:ok, {:new, %{id: :new_user, email: "test@example.com"}}, conn} = Plug.create_user(conn, "test_provider", %{"uid" => "new_user"}, %{"email" => "test@example.com"})
      assert conn.private[:plug_session]["pow_assent_auth"]
    end

    test "already taken user identity", %{conn: conn} do
      assert {:error, {:bound_to_different_user, %{}}, _conn} = Plug.create_user(conn, "test_provider", %{"uid" => "different_user"}, %{})
      refute conn.private[:plug_session]["pow_assent_auth"]
    end
  end

  describe "delete_identity/3" do
    setup do
      conn = setup_conn()

      conn = Pow.Plug.assign_current_user(conn, UserIdentitiesMock.user(), @default_config)

      {:ok, conn: conn}
    end

    test "deletes", %{conn: conn} do
      assert {:ok, {1, nil}, _conn} = Plug.delete_identity(conn, "test_provider")
    end

    test "with error", %{conn: conn} do
      conn = Pow.Plug.assign_current_user(conn, :error, @default_config)
      assert {:error, _changeset, _conn} = Plug.delete_identity(conn, "test_provider")
    end
  end

  describe "providers_for_current_user/1" do
    setup do
      conn = setup_conn()

      conn = Pow.Plug.assign_current_user(conn, UserIdentitiesMock.user(), @default_config)

      {:ok, conn: conn}
    end

    test "lists providers", %{conn: conn} do
      setup_oauth2_strategy_env(%Bypass{port: 1234})

      assert Plug.providers_for_current_user(conn) == [:test_provider]
    end

    test "with no user", %{conn: conn} do
      conn = Pow.Plug.assign_current_user(conn, nil, @default_config)

      assert Plug.providers_for_current_user(conn) == []
    end
  end

  describe "available_providers/1" do
    setup do
      conn = setup_conn()
      setup_oauth2_strategy_env(%Bypass{port: 1234})

      {:ok, conn: conn}
    end

    test "lists providers", %{conn: conn} do
      assert Plug.available_providers(conn) == [:test_provider]
    end

    test "with no available providers", %{conn: conn} do
      private = Map.put(conn.private, :pow_config, Keyword.put(@default_config, :otp_app, :my_app))
      conn = %{conn | private: private}

      assert Plug.available_providers(conn) == []
    end
  end
end
