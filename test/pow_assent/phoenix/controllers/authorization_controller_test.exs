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

  defmodule FailAuthorizeURL do
    @doc false
    def authorize_url(_config), do: {:error, "fail"}
  end

  describe "GET /auth/:provider/new" do
    test "redirects to authorization url", %{conn: conn, bypass: bypass} do
      conn = get conn, Routes.pow_assent_authorization_path(conn, :new, @provider)

      assert redirected_to(conn) =~ "http://localhost:#{bypass.port}/oauth/authorize?client_id=client_id&redirect_uri=http%3A%2F%2Flocalhost%2Fauth%2Ftest_provider%2Fcallback&response_type=code&state="
      assert Plug.Conn.get_session(conn, :pow_assent_session_params)[:state]
    end

    test "redirects with stored request_path", %{conn: conn} do
      conn = get(conn, Routes.pow_assent_authorization_path(conn, :new, @provider, request_path: "/custom-uri"))

      assert Plug.Conn.get_session(conn, :pow_assent_request_path) == "/custom-uri"
    end

    test "redirects with stored invitation_token", %{conn: conn} do
      conn = get conn, Routes.pow_assent_authorization_path(conn, :new, @provider, invitation_token: "token")

      assert Plug.Conn.get_session(conn, :pow_assent_invitation_token) == "token"
    end

    test "with error", %{conn: conn, bypass: bypass} do
      put_oauth2_env(bypass, strategy: FailAuthorizeURL)

      assert_raise RuntimeError, "fail", fn ->
        get(conn, Routes.pow_assent_authorization_path(conn, :new, @provider))
      end
    end
  end

  describe "GET /auth/:provider/callback" do
    setup %{conn: conn} do
      conn = Plug.Conn.put_session(conn, :pow_assent_session_params, %{state: "token"})

      {:ok, conn: conn}
    end

    test "with failed token response", %{conn: conn, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/oauth/token", fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "invalid_client"}))
      end)

      assert_raise Assent.RequestError, ~r/Server responded with status: 401/, fn ->
        get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)
      end
    end

    test "with timeout", %{conn: conn, bypass: bypass} do
      Bypass.down(bypass)

      assert_raise Assent.RequestError, ~r/Server was unreachable with Assent.HTTPAdapter.Httpc/, fn ->
        get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)
      end
    end

    test "with invalid state", %{conn: conn} do
      assert_raise Assent.CallbackCSRFError, fn ->
        get(conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, Map.put(@callback_params, :state, "invalid")))
      end
    end

    test "when identity exists authenticates", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{sub: "existing_user"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/session_created"
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)
    end

    test "with current user session when identity doesn't exist creates identity", %{conn: conn, bypass: bypass, user: user} do
      expect_oauth2_flow(bypass, user: %{sub: "new_identity"})

      conn =
        conn
        |> Pow.Plug.assign_current_user(user, [])
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == "/session_created"
      assert get_flash(conn, :info) == "signed_in_test_provider"
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)
    end

    test "with current user session when identity identity already bound to another user", %{conn: conn, bypass: bypass, user: user} do
      expect_oauth2_flow(bypass, user: %{sub: "identity_taken"})

      conn =
        conn
        |> Pow.Plug.assign_current_user(user, [])
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "The Test provider account is already bound to another user."
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)
    end

    test "when identity doesn't exist creates user", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{sub: "new_user"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert [user_identity] = user.user_identities
      assert user_identity.uid == "new_user"
      assert user_identity.provider == "test_provider"
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)
    end

    test "when identity doesn't exist and missing params", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{sub: "new_user", name: ""})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "Something went wrong, and you couldn't be signed in. Please try again."
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)
    end

    test "when identity doesn't exist and missing user id", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{email: ""})

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

    test "with stored request_path assigns to conn", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{sub: "existing_user"})

      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_request_path, "/custom-uri")
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == "/custom-uri"
      refute Plug.Conn.get_session(conn, :pow_assent_request_path)
    end
  end

  describe "POST /auth/:provider/callback" do
    setup %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_session_params, %{state: "token"})
        |> Plug.Conn.put_private(:plug_skip_csrf_protection, false)

      {:ok, conn: conn}
    end

    test "when identity doesn't exist creates user", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{sub: "new_user"})

      conn = post conn, Routes.pow_assent_authorization_path(conn, :callback, @provider), @callback_params

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert [user_identity] = user.user_identities
      assert user_identity.uid == "new_user"
      assert user_identity.provider == "test_provider"
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)
    end
  end

  alias PowAssent.Test.EmailConfirmation.Phoenix.Endpoint, as: EmailConfirmationEndpoint
  describe "GET /auth/:provider/callback with PowEmailConfirmation" do
    test "when identity doesn't exist and e-mail from provider isn't verified", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{sub: "new_user", email: "foo@example.com"})

      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_session_params, %{state: "token"})
        |> Phoenix.ConnTest.dispatch(EmailConfirmationEndpoint, :get, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      refute Pow.Plug.current_user(conn)

      assert redirected_to(conn) == "/registration_created"
      assert get_flash(conn, :error) == "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

      assert_received {:mail_mock, mail}
      mail.html =~ "http://example.com/confirm-email/"
    end

    test "when identity doesn't exist and e-mail from provider is verified", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{sub: "new_user", email: "foo@example.com", email_verified: true})

      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_session_params, %{state: "token"})
        |> Phoenix.ConnTest.dispatch(EmailConfirmationEndpoint, :get, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert user.email_confirmed_at
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)
    end

    test "when identity exists with unconfirmed e-mail", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{sub: "existing_user-missing_email_confirmation"})

      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_session_params, %{state: "token"})
        |> Phoenix.ConnTest.dispatch(EmailConfirmationEndpoint, :get, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      refute Pow.Plug.current_user(conn)

      assert redirected_to(conn) == "/session_created"
      assert get_flash(conn, :error) == "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

      assert_received {:mail_mock, mail}
      mail.html =~ "http://example.com/confirm-email/"
    end
  end

  alias PowAssent.Test.Invitation.Phoenix.Endpoint, as: InvitationEndpoint
  describe "GET /auth/:provider/callback as authentication with invitation" do
    test "with invitation_token updates user as accepted invitation", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{sub: "new_identity"})

      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_session_params, %{state: "token"})
        |> Plug.Conn.put_session(:pow_assent_invitation_token, "token")
        |> Phoenix.ConnTest.dispatch(InvitationEndpoint, :get, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == "/session_created"
      assert get_flash(conn, :info) == "signed_in_test_provider"
      assert user = Pow.Plug.current_user(conn)
      assert user.invitation_token == "token"
      refute Plug.Conn.get_session(conn, :pow_assent_invitation_token)
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)
    end
  end

  alias PowAssent.Test.NoRegistration.Phoenix.Endpoint, as: NoRegistrationEndpoint
  describe "GET /auth/:provider/callback as authentication with missing registration routes" do
    test "can't register", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{sub: "new_user"})

      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_session_params, %{state: "token"})
        |> Phoenix.ConnTest.dispatch(NoRegistrationEndpoint, :get, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      refute Pow.Plug.current_user(conn)
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "Something went wrong, and you couldn't be signed in. Please try again."
    end
  end

  describe "GET /auth/:provider/callback recording strategy params" do
    test "with new identity", %{conn: conn, bypass: bypass, user: user} do
      expect_oauth2_flow(bypass, user: %{sub: "new_identity_with_access_token"})

      conn =
        conn
        |> Pow.Plug.assign_current_user(user, [])
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == "/session_created"
    end

    test "with new user", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{sub: "new_user_with_access_token"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/registration_created"
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)
      assert user = Pow.Plug.current_user(conn)
      assert [user_identity] = user.user_identities
      assert user_identity.access_token == "access_token"
    end

    test "when identity exists updates identity", %{conn: conn, bypass: bypass} do
      expect_oauth2_flow(bypass, user: %{sub: "existing_user_with_access_token"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/session_created"
      refute Plug.Conn.get_session(conn, :pow_assent_session_params)
      assert Pow.Plug.current_user(conn)
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
