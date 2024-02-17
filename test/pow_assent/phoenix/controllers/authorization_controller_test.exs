defmodule PowAssent.Phoenix.AuthorizationControllerTest do
  use PowAssent.Test.Phoenix.ConnCase

  import PowAssent.Test.TestProvider, only: [set_oauth2_test_endpoints: 1, put_oauth2_env: 0, put_oauth2_env: 1]
  import ExUnit.CaptureLog

  alias Plug.Conn
  alias Pow.Plug, as: PowPlug
  alias PowAssent.Test.Ecto.Users.User
  alias PowInvitation.Plug, as: PowInvitationPlug

  @provider "test_provider"
  @callback_params %{code: "test", redirect_uri: "", state: "token"}

  setup do
    user = %User{id: 1}

    TestServer.start(scheme: :https)
    put_oauth2_env()

    {:ok, user: user}
  end

  defmodule FailAuthorizeURL do
    @doc false
    def authorize_url(_config), do: {:error, "fail"}
  end

  describe "GET /auth/:provider/new" do
    test "redirects to authorization url", %{conn: conn} do
      conn = get(conn, ~p"/auth/#{@provider}/new")

      assert redirected_to(conn) =~ TestServer.url("/oauth/authorize?client_id=client_id&")
      assert conn.resp_cookies["pow_assent_auth_session"]
      assert get_pow_assent_session(conn, :session_params)[:state]
    end

    test "redirects with stored request_path", %{conn: conn} do
      conn = get(conn, ~p"/auth/#{@provider}/new?#{[request_path: "/custom-uri"]}")

      assert conn.resp_cookies["pow_assent_auth_session"]
      assert get_pow_assent_session(conn, :request_path) == "/custom-uri"
    end

    test "redirects with stored invitation_token", %{conn: conn} do
      signed_token = sign_invitation_token(conn, "token")

      conn = get(conn, ~p"/auth/#{@provider}/new?#{[invitation_token: signed_token]}")

      assert conn.resp_cookies["pow_assent_auth_session"]
      assert get_pow_assent_session(conn, :invitation_token) == signed_token
    end

    test "with error", %{conn: conn} do
      put_oauth2_env(strategy: FailAuthorizeURL)

      assert capture_log(fn ->
        conn = get(conn, ~p"/auth/#{@provider}/new")

        assert redirected_to(conn) == ~p"/session/new"
        assert get_flash(conn, :error) == "Something went wrong, and you couldn't be signed in. Please try again."
        refute conn.resp_cookies["pow_assent_auth_session"]
        refute get_pow_assent_session(conn, :session_params)
      end) =~ "Strategy failed with error: fail"
    end
  end

  describe "GET /auth/:provider/callback" do
    @pow_assent_session %{session_params: %{state: "token"}}

    setup %{conn: conn} do
      conn = Conn.put_private(conn, :pow_assent_session, @pow_assent_session)

      {:ok, conn: conn}
    end

    test "with failed token response", %{conn: conn} do
      TestServer.add("/oauth/token", to: fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "invalid_client"}))
      end)

      log = capture_log(fn ->
        conn = get(conn, ~p"/auth/#{@provider}/callback?#{@callback_params}")

        assert redirected_to(conn) == ~p"/session/new"
        assert get_flash(conn, :error) == "Something went wrong, and you couldn't be signed in. Please try again."
        refute conn.resp_cookies["pow_assent_auth_session"]
        refute get_pow_assent_session(conn, :session_params)
      end)

      assert log =~ "Strategy failed with error: An invalid response was received."
      assert log =~ "HTTP Adapter: Assent.HTTPAdapter.Httpc"
      assert log =~ "Response status: 401"
    end

    test "with timeout", %{conn: conn} do
      TestServer.stop()

      log = capture_log(fn ->
        conn = get(conn, ~p"/auth/#{@provider}/callback?#{@callback_params}")

        assert redirected_to(conn) == ~p"/session/new"
        assert get_flash(conn, :error) == "Something went wrong, and you couldn't be signed in. Please try again."
        refute conn.resp_cookies["pow_assent_auth_session"]
        refute get_pow_assent_session(conn, :session_params)
      end)

      assert log =~ "Strategy failed with error: The server was unreachable."
      assert log =~ "HTTP Adapter: Assent.HTTPAdapter.Httpc"
      assert log =~ ":econnrefused"
    end

    test "with invalid state", %{conn: conn} do
      assert capture_log(fn ->
        conn = get(conn, ~p"/auth/#{@provider}/callback?#{Map.put(@callback_params, :state, "invalid")}")

        assert redirected_to(conn) == ~p"/session/new"
        assert get_flash(conn, :error) == "Something went wrong, and you couldn't be signed in. Please try again."
        refute conn.resp_cookies["pow_assent_auth_session"]
        refute get_pow_assent_session(conn, :session_params)
      end) =~ "Strategy failed with error: CSRF detected with param key \"state\""
    end

    test "when identity exists authenticates", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "existing_user"})

      conn = get(conn, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == "/session_created"

      refute conn.resp_cookies["pow_assent_auth_session"]
      refute get_pow_assent_session(conn, :session_params)
    end

    test "when identity exist and pow_assent_registration: false authenticates", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "existing_user"})

      conn =
        conn
        |> Conn.put_private(:pow_assent_registration, false)
        |> get(~p"/auth/#{@provider}/callback?#{@callback_params}")

        assert redirected_to(conn) == "/session_created"

        refute conn.resp_cookies["pow_assent_auth_session"]
        refute get_pow_assent_session(conn, :session_params)
    end

    test "with current user session when identity doesn't exist creates identity", %{conn: conn, user: user} do
      set_oauth2_test_endpoints(user: %{sub: "new_identity"})

      conn =
        conn
        |> Pow.Plug.assign_current_user(user, [])
        |> get(~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == "/session_created"
      assert get_flash(conn, :info) == "signed_in_test_provider"
      refute conn.resp_cookies["pow_assent_auth_session"]
      refute get_pow_assent_session(conn, :session_params)
    end

    test "with current user session when identity identity already bound to another user", %{conn: conn, user: user} do
      set_oauth2_test_endpoints(user: %{sub: "identity_taken"})

      conn =
        conn
        |> Pow.Plug.assign_current_user(user, [])
        |> get(~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == ~p"/session/new"
      assert get_flash(conn, :error) == "The Test provider account is already bound to another user."
      refute conn.resp_cookies["pow_assent_auth_session"]
      refute get_pow_assent_session(conn, :session_params)
    end

    test "when identity doesn't exist creates user", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "new_user"})

      conn = get(conn, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert [user_identity] = user.user_identities
      assert user_identity.uid == "new_user"
      assert user_identity.provider == "test_provider"
      refute conn.resp_cookies["pow_assent_auth_session"]
      refute get_pow_assent_session(conn, :session_params)
    end

    test "when identity doesn't exist and missing params", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "new_user", name: ""})

      assert capture_log(fn ->
        conn = get(conn, ~p"/auth/#{@provider}/callback?#{@callback_params}")

        assert redirected_to(conn) == ~p"/session/new"
        assert get_flash(conn, :error) == "Something went wrong, and you couldn't be signed in. Please try again."
        refute conn.resp_cookies["pow_assent_auth_session"]
        refute get_pow_assent_session(conn, :session_params)
      end) =~ "Unexpected error inserting user: #Ecto.Changeset<action: :insert"
    end

    test "when identity doesn't exist and missing user id", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{email: ""})

      conn = get(conn, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == ~p"/auth/test_provider/add-user-id"
      assert conn.resp_cookies["pow_assent_auth_session"]
      assert %{"test_provider" => %{user_identity: user_identity, user: user}} = get_pow_assent_session(conn, :callback_params)
      assert user_identity == %{"provider" => "test_provider", "uid" => "new_user", "token" => %{"access_token" => "access_token"}, "userinfo" => %{"email" => "", "name" => "John Doe", "sub" => "new_user"}}
      assert user == %{"name" => "John Doe", "email" => ""}
      refute get_pow_assent_session(conn, :session_params)
      assert get_pow_assent_session(conn, :callback_params)
      assert get_pow_assent_session(conn, :changeset)
    end

    test "when identity doesn't exist and and user id taken by other user", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{email: "taken@example.com"})
      ~p"/auth/#{@provider}/callback?#{@callback_params}"
      conn = get(conn, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == ~p"/auth/test_provider/add-user-id"
      assert conn.resp_cookies["pow_assent_auth_session"]
      assert %{"test_provider" => %{user_identity: user_identity, user: user}} = get_pow_assent_session(conn, :callback_params)
      assert user_identity == %{"provider" => "test_provider", "uid" => "new_user", "token" => %{"access_token" => "access_token"}, "userinfo" => %{"email" => "taken@example.com", "name" => "John Doe", "sub" => "new_user"}}
      assert user == %{"name" => "John Doe", "email" => "taken@example.com"}
      refute get_pow_assent_session(conn, :session_params)
      assert get_pow_assent_session(conn, :callback_params)
      assert get_pow_assent_session(conn, :changeset)
    end

    test "when identity doesn't exist and pow_assent_registration: false", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "new_user"})

      conn =
        conn
        |> Conn.put_private(:pow_assent_registration, false)
        |> get(~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == ~p"/session/new"
      assert get_flash(conn, :error) == "Something went wrong, and you couldn't be signed in. Please try again."
      refute conn.resp_cookies["pow_assent_auth_session"]
      refute get_pow_assent_session(conn, :session_params)
    end

    test "with stored request_path assigns to conn", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "existing_user"})

      conn =
        conn
        |> Conn.put_private(:pow_assent_session, Map.put(@pow_assent_session, :request_path, "/custom-uri"))
        |> get(~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == "/custom-uri"
      refute conn.resp_cookies["pow_assent_auth_session"]
      refute get_pow_assent_session(conn, :request_path)
    end
  end

  describe "POST /auth/:provider/callback" do
    @pow_assent_session %{session_params: %{state: "token"}}

    setup %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_assent_session, @pow_assent_session)
        |> Conn.put_private(:plug_skip_csrf_protection, false)

      {:ok, conn: conn}
    end

    test "when identity doesn't exist creates user", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "new_user"})

      conn = post(conn, ~p"/auth/#{@provider}/callback", @callback_params)

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert [user_identity] = user.user_identities
      assert user_identity.uid == "new_user"
      assert user_identity.provider == "test_provider"
      refute conn.resp_cookies["pow_assent_auth_session"]
      refute get_pow_assent_session(conn, :session_params)
    end
  end

  alias PowAssent.Test.EmailConfirmation.Phoenix.Endpoint, as: EmailConfirmationEndpoint
  describe "GET /auth/:provider/callback with PowEmailConfirmation" do
    @pow_assent_session %{session_params: %{state: "token"}}

    setup %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_assent_session, @pow_assent_session)
        |> Conn.put_private(:plug_skip_csrf_protection, false)

      {:ok, conn: conn}
    end

    test "when user doesn't exist", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "new_user", email: "foo@example.com"})

      conn = Phoenix.ConnTest.dispatch(conn, EmailConfirmationEndpoint, :get, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      refute Pow.Plug.current_user(conn)

      assert redirected_to(conn) == "/registration_created"
      assert get_flash(conn, :info) == "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

      assert_received {:mail_mock, mail}
      mail.html =~ "http://example.com/confirm-email/"
    end

    test "when user doesn't exist and provider e-mail is verified", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "new_user", email: "foo@example.com", email_verified: true})

      conn = Phoenix.ConnTest.dispatch(conn, EmailConfirmationEndpoint, :get, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert user.email_confirmed_at
      refute conn.resp_cookies["pow_assent_auth_session"]
      refute get_pow_assent_session(conn, :session_params)
    end

    test "when user doesn't exist and provider e-mail taken", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "new_user", email: "taken@example.com"})

      conn = Phoenix.ConnTest.dispatch(conn, EmailConfirmationEndpoint, :get, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      refute Pow.Plug.current_user(conn)

      assert redirected_to(conn) == "/registration_created"
      assert get_flash(conn, :info) == "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

      refute_received {:mail_mock, _mail}
    end

    test "when user doesn't exist and provider e-mail taken and provider e-mail is verified", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "new_user", email: "taken@example.com", email_verified: true})

      conn = Phoenix.ConnTest.dispatch(conn, EmailConfirmationEndpoint, :get, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == ~p"/auth/test_provider/add-user-id"
      assert conn.resp_cookies["pow_assent_auth_session"]
      assert %{"test_provider" => %{user_identity: user_identity, user: user}} = get_pow_assent_session(conn, :callback_params)
      assert user_identity == %{"provider" => "test_provider", "uid" => "new_user", "token" => %{"access_token" => "access_token"}, "userinfo" => %{"email" => "taken@example.com", "email_verified" => true, "name" => "John Doe", "sub" => "new_user"}}
      assert user == %{"name" => "John Doe", "email" => "taken@example.com", "email_verified" => true}
      refute get_pow_assent_session(conn, :session_params)
      assert get_pow_assent_session(conn, :callback_params)
      assert get_pow_assent_session(conn, :changeset)
    end

    test "when user exists with unconfirmed e-mail", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "existing_user-missing_email_confirmation"})

      conn = Phoenix.ConnTest.dispatch(conn, EmailConfirmationEndpoint, :get, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      refute Pow.Plug.current_user(conn)

      assert redirected_to(conn) == "/session_created"
      assert get_flash(conn, :info) == "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

      assert_received {:mail_mock, mail}
      mail.html =~ "http://example.com/confirm-email/"
    end
  end

  alias PowAssent.Test.Invitation.Phoenix.Endpoint, as: InvitationEndpoint
  describe "GET /auth/:provider/callback as authentication with invitation" do
    test "with invitation_token updates user as accepted invitation", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "new_identity"})

      signed_token = sign_invitation_token(conn, "token")
      session      = %{session_params: %{state: "token"}, invitation_token: signed_token}

      conn =
        conn
        |> Conn.put_private(:pow_assent_session, session)
        |> Phoenix.ConnTest.dispatch(InvitationEndpoint, :get, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == "/session_created"
      assert get_flash(conn, :info) == "signed_in_test_provider"
      assert user = Pow.Plug.current_user(conn)
      assert user.invitation_token == "token"
      refute conn.resp_cookies["pow_assent_auth_session"]
      refute get_pow_assent_session(conn, :invitation_token)
      refute get_pow_assent_session(conn, :session_params)
    end
  end

  alias PowAssent.Test.NoRegistration.Phoenix.Endpoint, as: NoRegistrationEndpoint
  describe "GET /auth/:provider/callback as authentication with missing registration routes" do
    @pow_assent_session %{session_params: %{state: "token"}}

    test "can't register", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "new_user"})

      conn =
        conn
        |> Conn.put_private(:pow_assent_session, @pow_assent_session)
        |> Phoenix.ConnTest.dispatch(NoRegistrationEndpoint, :get, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      refute Pow.Plug.current_user(conn)
      refute conn.resp_cookies["pow_assent_auth_session"]
      refute get_pow_assent_session(conn, :session_params)

      assert redirected_to(conn) == ~p"/session/new"
      assert get_flash(conn, :error) == "Something went wrong, and you couldn't be signed in. Please try again."
    end
  end

  alias PowAssent.Test.WithCustomChangeset.Phoenix.Endpoint, as: WithCustomChangesetEndpoint
  alias PowAssent.Test.WithCustomChangeset.Users.User, as: WithCustomChangesetUser
  describe "GET /auth/:provider/callback recording strategy params" do
    setup %{conn: conn} do
      user = %WithCustomChangesetUser{id: 1}
      conn = Conn.put_private(conn, :pow_assent_session, %{session_params: %{}})

      {:ok, user: user, conn: conn}
    end

    test "with new identity", %{conn: conn, user: user} do
      set_oauth2_test_endpoints(user: %{sub: "new_identity"})

      conn =
        conn
        |> Pow.Plug.assign_current_user(user, [])
        |> Phoenix.ConnTest.dispatch(WithCustomChangesetEndpoint, :get, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == "/session_created"
    end

    test "with new user", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "new_user"})

      conn = Phoenix.ConnTest.dispatch(conn, WithCustomChangesetEndpoint, :get, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == "/registration_created"
      refute conn.resp_cookies["pow_assent_auth_session"]
      refute get_pow_assent_session(conn, :session_params)
      assert user = Pow.Plug.current_user(conn)
      assert [user_identity] = user.user_identities
      assert user_identity.access_token == "access_token"
      assert user_identity.name == "John Doe"
    end

    test "when identity exists updates identity", %{conn: conn} do
      set_oauth2_test_endpoints(user: %{sub: "existing_user"})

      conn = Phoenix.ConnTest.dispatch(conn, WithCustomChangesetEndpoint, :get, ~p"/auth/#{@provider}/callback?#{@callback_params}")

      assert redirected_to(conn) == "/session_created"
      refute conn.resp_cookies["pow_assent_auth_session"]
      refute get_pow_assent_session(conn, :session_params)
      assert Pow.Plug.current_user(conn)
    end
  end

  describe "DELETE /auth/:provider" do
    test "when password not set", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(%User{id: 1, password_hash: nil}, [])
        |> delete(~p"/auth/#{@provider}")

      assert redirected_to(conn) == ~p"/registration/edit"
      assert get_flash(conn, :error) == "Authentication cannot be removed until you've entered a password for your account."
    end

    test "when password not set but has multiple identities", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(%User{id: :multiple_identities, password_hash: nil}, [])
        |> delete(~p"/auth/#{@provider}")

      assert redirected_to(conn) == ~p"/registration/edit"
      assert get_flash(conn, :info) == "Authentication with Test provider has been removed"
    end

    test "when can be deleted", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(%User{id: 1, password_hash: ""}, [])
        |> delete(~p"/auth/#{@provider}")

      assert redirected_to(conn) == ~p"/registration/edit"
      assert get_flash(conn, :info) == "Authentication with Test provider has been removed"
    end
  end

  defp get_pow_assent_session(conn, key) do
    Map.get(conn.private[:pow_assent_session], key)
  end

  defp sign_invitation_token(conn, token) do
    %{conn | secret_key_base: InvitationEndpoint.config(:secret_key_base)}
    |> PowPlug.put_config([])
    |> PowInvitationPlug.sign_invitation_token(%{invitation_token: token})
  end
end
