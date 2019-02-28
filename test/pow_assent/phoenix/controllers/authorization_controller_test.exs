defmodule PowAssent.Phoenix.AuthorizationControllerTest do
  use PowAssent.Test.Phoenix.ConnCase

  import PowAssent.OAuthHelpers
  alias PowAssent.Test.{Ecto.Users.User, UserIdentitiesMock}

  @provider "test_provider"
  @callback_params %{code: "test", redirect_uri: ""}

  setup %{conn: conn} do
    server = Bypass.open()

    setup_oauth2_strategy_env(server)

    {:ok, conn: conn, user: %User{id: :loaded}, server: server}
  end

  describe "GET /auth/:provider/new" do
    test "redirects to authorization url", %{conn: conn, server: server} do
      conn = get conn, Routes.pow_assent_authorization_path(conn, :new, @provider)

      assert redirected_to(conn) =~ "#{bypass_server(server)}/oauth/authorize?client_id=client_id&redirect_uri=http%3A%2F%2Flocalhost%2Fauth%2Ftest_provider%2Fcallback&response_type=code&state="
    end

    test "with error", %{conn: conn} do
      assert_raise RuntimeError, "fail", fn ->
        conn
        |> Plug.Conn.put_private(:fail_authorize_url, true)
        |> get(Routes.pow_assent_authorization_path(conn, :new, @provider))
      end
    end
  end

  describe "GET /auth/:provider/callback with current user session" do
    test "adds identity", %{conn: conn, server: server, user: user} do
      expect_oauth2_flow(server, user: %{uid: "new_identity"})

      conn =
        conn
        |> Pow.Plug.assign_current_user(user, [])
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == "/session_created"
      assert get_flash(conn, :info) == "signed_in_test_provider"
      assert Pow.Plug.current_user(conn) == user
    end

    test "with identity bound to another user", %{conn: conn, server: server, user: user} do
      expect_oauth2_flow(server, user: %{uid: "new_identity"})

      conn =
        conn
        |> Pow.Plug.assign_current_user(%{user | id: :bound_to_different_user}, [])
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :new)
      assert get_flash(conn, :error) == "The Test provider account is already bound to another user."
    end
  end

  describe "GET /auth/:provider/callback as authentication" do
    test "with valid params", %{conn: conn, server: server} do
      expect_oauth2_flow(server, user: %{uid: "existing_user"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/session_created"
    end
  end

  describe "GET /auth/:provider/callback as authentication with email confirmation" do
    test "with missing e-mail confirmation", %{conn: conn, server: server} do
      expect_oauth2_flow(server, user: %{uid: "new_user-missing_email_confirmation"})

      conn = Phoenix.ConnTest.dispatch conn, PowAssent.Test.Phoenix.EndpointConfirmEmail, :get, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      refute Pow.Plug.current_user(conn)

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

      assert_received {:mail_mock, mail}
      mail.html =~ "http://example.com/confirm-email/"
    end
  end

  describe "GET /auth/:provider/callback as registration" do
    test "with valid params", %{conn: conn, server: server} do
      expect_oauth2_flow(server, user: %{uid: "new_user"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert [user_identity] = user.user_identities
      assert user_identity.uid == "new_user"
      assert user_identity.provider == "test_provider"
    end

    test "with missing params", %{conn: conn, server: server} do
      expect_oauth2_flow(server, user: %{uid: "new_user", name: ""})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "Something went wrong, and you couldn't be signed in. Please try again."
    end

    test "with missing required user id", %{conn: conn, server: server} do
      expect_oauth2_flow(server, user: %{"email" => ""})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Routes.pow_assent_registration_path(conn, :add_user_id, "test_provider")
      assert Plug.Conn.get_session(conn, "pow_assent_params") == %{"name" => "Dan Schultzer", "uid" => "new_user", "email" => ""}
    end

    test "with an existing required user id", %{conn: conn, server: server} do
      expect_oauth2_flow(server, user: %{email: "taken@example.com"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Routes.pow_assent_registration_path(conn, :add_user_id, "test_provider")
      assert Plug.Conn.get_session(conn, "pow_assent_params") == %{"email" => "taken@example.com", "name" => "Dan Schultzer", "uid" => "new_user"}
    end
  end

  describe "GET /auth/:provider/callback" do
    test "with failed token generation", %{conn: conn, server: server} do
      Bypass.expect_once(server, "POST", "/oauth/token", fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "invalid_client"}))
      end)

      message = ~r/Server responded with status: 401/

      assert_raise PowAssent.RequestError, message, fn ->
        get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)
      end
    end

    test "with differing state", %{conn: conn} do
      assert_raise PowAssent.CallbackCSRFError, fn ->
        conn
        |> Plug.Conn.put_session(:pow_assent_state, "1")
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, Map.merge(@callback_params, %{"state" => "2"})))
      end
    end

    test "with same state", %{conn: conn, server: server} do
      expect_oauth2_flow(server, user: %{"email" => ""})

      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_state, "1")
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, Map.merge(@callback_params, %{"state" => "1"})))

      assert redirected_to(conn) == "/auth/test_provider/add-user-id"
      refute Plug.Conn.get_session(conn, :pow_assent_state)
    end

    test "with timeout", %{conn: conn, server: server} do
      Bypass.down(server)

      assert_raise RuntimeError, "Connection refused", fn ->
        get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)
      end
    end
  end

  describe "DELETE /auth/:provider" do
    test "when requires a user password set", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(:no_password, [])
        |> delete(Routes.pow_assent_authorization_path(conn, :delete, @provider))

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :error) == "Authentication cannot be removed until you've entered a password for your account."
    end

    test "when can be deleted", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(UserIdentitiesMock.user(), [])
        |> delete(Routes.pow_assent_authorization_path(conn, :delete, @provider))

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :info) == "Authentication with Test provider has been removed"
    end
  end
end
