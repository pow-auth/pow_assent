defmodule PowAssent.Phoenix.CustomUserAuthorizationControllerTest do
  use PowAssent.Test.Phoenix.ConnCase

  import PowAssent.Test.TestProvider, only: [expect_oauth2_flow: 2, put_oauth2_env: 1]

  alias PowAssent.Test.Ecto.Users.CustomUser

  @provider "test_provider"
  @callback_params %{code: "test", redirect_uri: "", state: "token"}

  setup _context do
    user   = %CustomUser{id: :loaded}
    bypass = Bypass.open()

    put_oauth2_env(bypass)

    {:ok, user: user, bypass: bypass}
  end

  describe "GET /auth/:provider/callback" do
    setup %{conn: conn} do
      conn = Plug.Conn.put_session(conn, :pow_assent_session_params, %{state: "token"})

      {:ok, conn: conn}
    end

    test "when identity doesn't exist and missing user id", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{user_name: ""})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Routes.pow_assent_registration_path(conn, :add_user_id, "test_provider")
      assert %{"test_provider" => %{user_identity: user_identity, user: user}} = Plug.Conn.get_session(conn, :pow_assent_params)
      assert user_identity == %{"provider" => "test_provider", "uid" => "new_user", "token" => %{"access_token" => "access_token"}}
      assert user == %{"name" => "Dan Schultzer", "email" => ""}
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)
    end

    test "when identity doesn't exist and and user id taken by other user", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{email: "taken@example.com"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Routes.pow_assent_registration_path(conn, :add_user_id, "test_provider")
      assert %{"test_provider" => %{user_identity: user_identity, user: user}} = Plug.Conn.get_session(conn, :pow_assent_params)
      assert user_identity == %{"provider" => "test_provider", "uid" => "new_user", "token" => %{"access_token" => "access_token"}}
      assert user == %{"name" => "Dan Schultzer", "email" => "taken@example.com"}
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)
    end
  end
end
