defmodule PowAssent.Phoenix.AuthorizationControllerTest do
  use PowAssent.Test.Phoenix.ConnCase

  import OAuth2.TestHelpers
  alias PowAssent.Test.Ecto.Users.User

  @provider "test_provider"
  @callback_params %{code: "test", redirect_uri: ""}

  setup %{conn: conn} do
    server = Bypass.open()

    Application.put_env(:pow_assent, :pow_assent,
      providers: [
        test_provider: [
          client_id: "client_id",
          client_secret: "abc123",
          site: bypass_server(server),
          strategy: TestProvider
        ]
      ])

    {:ok, conn: conn, user: %User{id: 1}, server: server}
  end

  defp bypass_oauth(server, token_params \\ %{}, user_params \\ %{}) do
    Bypass.expect_once server, "POST", "/oauth/token", fn conn ->
      send_resp(conn, 200, Poison.encode!(Map.merge(%{access_token: "access_token"}, token_params)))
    end

    Bypass.expect_once server, "GET", "/api/user", fn conn ->
      send_resp(conn, 200, Poison.encode!(Map.merge(%{uid: "1", name: "Dan Schultzer"}, user_params)))
    end
  end

  describe "GET /auth/:provider/new" do
    test "redirects to authorization url", %{conn: conn, server: server} do
      conn = get conn, Routes.pow_assent_authorization_path(conn, :new, @provider)

      assert redirected_to(conn) =~ "http://localhost:#{server.port}/oauth/authorize?client_id=client_id&redirect_uri=http%3A%2F%2Flocalhost%2Fauth%2Ftest_provider%2Fcallback&response_type=code&state="
    end
  end

  describe "GET /auth/:provider/callback with current user session" do
    test "adds identity", %{conn: conn, server: server, user: user} do
      bypass_oauth(server)

      conn =
        conn
        |> Pow.Plug.assign_current_user(user, [])
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == "/session_created"
      assert get_flash(conn, :info) == "signed_in_test_provider"
      assert Pow.Plug.current_user(conn) == user
    end

    test "with identity bound to another user", %{conn: conn, server: server, user: user} do
      bypass_oauth(server, %{}, %{uid: "duplicate"})

      conn =
        conn
        |> Pow.Plug.assign_current_user(user, [])
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :new)
      assert get_flash(conn, :error) == "The Test provider account is already bound to another user."
    end
  end

  describe "GET /auth/:provider/callback as authentication" do
    test "with valid params", %{conn: conn, server: server} do
      bypass_oauth(server, %{}, %{uid: "existing"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/session_created"
    end
  end

  describe "GET /auth/:provider/callback as authentication with email confirmation" do
    setup %{conn: conn} do
      Application.put_env(:pow_assent_test, :config,
        user: PowAssent.Test.Ecto.Users.EmailConfirmUser,
        mailer_backend: PowAssent.Test.Phoenix.MailerMock)

      on_exit(fn -> Application.put_env(:pow_assent_test, :config, []) end)

      {:ok, conn: conn}
    end

    test "with missing e-mail confirmation", %{conn: conn, server: server} do
      bypass_oauth(server, %{}, %{uid: "user-missing-email-confirmation"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)
      refute Pow.Plug.current_user(conn)

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

      assert_received {:mail_mock, mail}
      mail.html =~ "http://example.com/confirm-email/"
    end
  end

  describe "GET /auth/:provider/callback as registration" do
    test "with valid params", %{conn: conn, server: server} do
      bypass_oauth(server, %{}, %{email: "newuser@example.com"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert [user_identity] = user.user_identities
      assert user_identity.uid == "1"
      assert user_identity.provider == "test_provider"
    end

    test "with missing params", %{conn: conn, server: server} do
      bypass_oauth(server, %{}, %{email: "newuser@example.com", name: ""})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "Something went wrong, and you couldn't be singed in. Please try again."
    end

    test "with missing required user id", %{conn: conn, server: server} do
      bypass_oauth(server)

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Routes.pow_assent_registration_path(conn, :add_user_id, "test_provider")
      assert Plug.Conn.get_session(conn, "pow_assent_params") == %{"name" => "Dan Schultzer", "uid" => "1"}
    end

    test "with an existing required user id", %{conn: conn, server: server} do
      bypass_oauth(server, %{}, %{email: "taken@example.com"})

      conn = get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Routes.pow_assent_registration_path(conn, :add_user_id, "test_provider")
      assert Plug.Conn.get_session(conn, "pow_assent_params") == %{"email" => "taken@example.com", "name" => "Dan Schultzer", "uid" => "1"}
    end
  end

  describe "GET /auth/:provider/callback" do
    test "with failed token generation", %{conn: conn, server: server} do
      Bypass.expect_once server, "POST",  "/oauth/token", fn conn ->
        send_resp(conn, 401, Poison.encode!(%{error: "invalid_client"}))
      end

      assert_raise PowAssent.RequestError, "invalid_client", fn ->
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
      bypass_oauth(server)

      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_state, "1")
        |> get(Routes.pow_assent_authorization_path(conn, :callback, @provider, Map.merge(@callback_params, %{"state" => "1"})))

      assert redirected_to(conn) == "/auth/test_provider/add-user-id"
      refute Plug.Conn.get_session(conn, :pow_assent_state)
    end

    test "with timeout", %{conn: conn, server: server} do
      Bypass.down(server)

      assert_raise OAuth2.Error, "Connection refused", fn ->
        get conn, Routes.pow_assent_authorization_path(conn, :callback, @provider, @callback_params)
      end
    end
  end

  describe "DELETE /auth/:provider" do
    test "with no user password", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(%User{id: :with_user_identity}, [])
        |> delete(Routes.pow_assent_authorization_path(conn, :delete, @provider))

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :error) == "Authentication cannot be removed until you've entered a password for your account."
    end

    test "with two identities", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(%User{id: :with_two_user_identities}, [])
        |> delete(Routes.pow_assent_authorization_path(conn, :delete, @provider))

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :info) == "Authentication with Test provider has been removed"
    end

    test "with user password", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(%User{id: :with_user_identity, password_hash: :set}, [])
        |> delete(Routes.pow_assent_authorization_path(conn, :delete, @provider))

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :info) == "Authentication with Test provider has been removed"
    end

    test "with current_user session without provider", %{conn: conn, user: user} do
      conn = conn
        |> Pow.Plug.assign_current_user(user, [])
        |> delete(Routes.pow_assent_authorization_path(conn, :delete, @provider))

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :error) == "Authentication cannot be removed until you've entered a password for your account."
    end
  end
end
