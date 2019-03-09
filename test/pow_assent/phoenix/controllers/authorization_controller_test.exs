defmodule PowAssent.Phoenix.AuthorizationControllerTest do
  use PowAssent.Test.Phoenix.ConnCase

  import PowAssent.Test.TestProvider, only: [expect_oauth2_flow: 2, put_oauth2_env: 1, put_oauth2_env: 2]

  alias PowAssent.Test.{Ecto.Users.User, UserIdentitiesMock}

  @provider "test_provider"
  @callback_params %{code: "test", redirect_uri: "", state: "token"}

  setup _context do
    user   = %User{id: :loaded}
    bypass = Bypass.open()

    put_oauth2_env(bypass)

    {:ok, user: user, bypass: bypass}
  end

  describe "GET /auth/:provider/new" do
    test "redirects to authorization url", %{conn: conn, bypass: bypass} do
      conn = get conn, Routes.pow_assent_authorization_path(conn, :new, @provider)

      assert redirected_to(conn) =~ "http://localhost:#{bypass.port}/oauth/authorize?client_id=client_id&redirect_uri=http%3A%2F%2Flocalhost%2Fauth%2Ftest_provider%2Fcallback&response_type=code&state="
      assert Plug.Conn.get_session(conn, :pow_assent_state)
    end

    test "with error", %{conn: conn, bypass: bypass} do
      put_oauth2_env(bypass, fail_authorize_url: true)

      assert_raise RuntimeError, "fail", fn ->
        get(conn, Routes.pow_assent_authorization_path(conn, :new, @provider))
      end
    end
  end

  describe "GET /auth/:provider/callback" do
    setup %{conn: conn} do
      conn = Plug.Conn.put_session(conn, :pow_assent_state, "token")

      {:ok, conn: conn}
    end

    test "with failed token response", %{conn: conn, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "invalid_client"}))
      end)

      assert_raise PowAssent.RequestError, ~r/Server responded with status: 401/, fn ->
        get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)
      end
    end

    test "with timeout", %{conn: conn, bypass: bypass} do
      Bypass.down(bypass)

      assert_raise PowAssent.RequestError, ~r/Server was unreachable with PowAssent.HTTPAdapter.Httpc/, fn ->
        get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)
      end
    end

    test "with invalid state", %{conn: conn} do
      assert_raise PowAssent.CallbackCSRFError, fn ->
        get(conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, Map.put(@callback_params, :state, "invalid")))
      end
    end

    test "when identity exists authenticates", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{uid: "existing_user"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/session_created"
      refute Plug.Conn.get_session(conn, :pow_assent_state)
    end

    test "with current user session when identity doesn't exist creates identity", %{conn: conn, bypass: bypass, user: user} do
      expect_oauth2_flow(bypass, user: %{uid: "new_identity"})

      conn =
        conn
        |> Pow.Plug.assign_current_user(user, [])
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == "/session_created"
      assert get_flash(conn, :info) == "signed_in_test_provider"
      assert Pow.Plug.current_user(conn) == user
      refute Plug.Conn.get_session(conn, :pow_assent_state)
    end

    test "with current user session when identity identity already bound to another user", %{conn: conn, bypass: bypass, user: user} do
      expect_oauth2_flow(bypass, user: %{uid: "identity_taken"})

      conn =
        conn
        |> Pow.Plug.assign_current_user(user, [])
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "The Test provider account is already bound to another user."
      refute Plug.Conn.get_session(conn, :pow_assent_state)
    end

    test "when identity doesn't exist creates user", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{uid: "new_user"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert [user_identity] = user.user_identities
      assert user_identity.uid == "new_user"
      assert user_identity.provider == "test_provider"
      refute Plug.Conn.get_session(conn, :pow_assent_state)
    end

    test "when identity doesn't exist and missing params", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{uid: "new_user", name: ""})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "Something went wrong, and you couldn't be signed in. Please try again."
      refute Plug.Conn.get_session(conn, :pow_assent_state)
    end

    test "when identity doesn't exist and missing user id", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{email: ""})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Routes.pow_assent_registration_path(conn, :add_user_id, "test_provider")
      assert Plug.Conn.get_session(conn, :pow_assent_params) == %{"test_provider" => %{"name" => "Dan Schultzer", "uid" => "new_user", "email" => ""}}
      refute Plug.Conn.get_session(conn, :pow_assent_state)
    end

    test "when identity doesn't exist and and user id taken by other user", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{email: "taken@example.com"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Routes.pow_assent_registration_path(conn, :add_user_id, "test_provider")
      assert Plug.Conn.get_session(conn, :pow_assent_params) == %{"test_provider" => %{"name" => "Dan Schultzer", "uid" => "new_user", "email" => "taken@example.com"}}
      refute Plug.Conn.get_session(conn, :pow_assent_state)
    end
  end

  alias PowAssent.Test.EmailConfirmation.Phoenix.Endpoint, as: EmailConfirmationEndpoint
  describe "GET /auth/:provider/callback as authentication with email confirmation" do
    test "with missing e-mail confirmation", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{uid: "new_user-missing_email_confirmation"})

      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_state, "token")
        |> Phoenix.ConnTest.dispatch(EmailConfirmationEndpoint, :get, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      refute Pow.Plug.current_user(conn)

      assert redirected_to(conn) == "/session_created"
      assert get_flash(conn, :error) == "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

      assert_received {:mail_mock, mail}
      mail.html =~ "http://example.com/confirm-email/"
    end
  end

  alias PowAssent.Test.NoRegistration.Phoenix.Endpoint, as: NoRegistrationEndpoint
  describe "GET /auth/:provider/callback as authentication with missing registration routes" do
    test "can't register", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{uid: "new_user"})

      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_state, "token")
        |> Phoenix.ConnTest.dispatch(NoRegistrationEndpoint, :get, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      refute Pow.Plug.current_user(conn)
      refute Plug.Conn.get_session(conn, :pow_assent_state)

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "Something went wrong, and you couldn't be signed in. Please try again."
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
