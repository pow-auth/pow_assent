defmodule PowAssent.Phoenix.RegistrationControllerTest do
  use PowAssent.Test.Phoenix.ConnCase

  @provider "test_provider"
  @token_params %{"access_token" => "access_token"}
  @user_identity_params %{"provider" => @provider, "uid" => "new_user", "token" => @token_params}
  @user_params %{"name" => "John Doe"}

  defp provider_params(opts \\ []) do
    user_identity_params = Map.merge(@user_identity_params, Keyword.get(opts, :user_identity_params, %{}))
    user_params = Map.merge(@user_params, Keyword.get(opts, :user_params, %{}))

    %{@provider => %{user_identity: user_identity_params, user: user_params}}
  end

  setup %{conn: conn} do
    conn = Plug.Conn.put_session(conn, :pow_assent_params, provider_params())

    {:ok, conn: conn}
  end

  describe "GET /auth/:provider/add-user-id" do
    test "with missing session params", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.delete_session(:pow_assent_params)
        |> get(Routes.pow_assent_registration_path(conn, :add_user_id, @provider))

      assert redirected_to(conn) == "/logged-out"
      assert get_flash(conn, :error) == "Invalid Request."
    end

    test "with invalid provider path", %{conn: conn} do
      conn = get conn, Routes.pow_assent_registration_path(conn, :add_user_id, "invalid")

      assert redirected_to(conn) == "/logged-out"
      assert get_flash(conn, :error) == "Invalid Request."
    end

    test "shows", %{conn: conn} do
      conn = get conn, Routes.pow_assent_registration_path(conn, :add_user_id, @provider)

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\">"
    end
  end

  describe "POST /auth/:provider/create" do
    @valid_params %{user: %{email: "foo@example.com"}}
    @taken_params %{user: %{email: "taken@example.com"}}

    test "with missing session params", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.delete_session(:pow_assent_params)
        |> post(Routes.pow_assent_registration_path(conn, :create, @provider), @valid_params)

      assert redirected_to(conn) == "/logged-out"
      assert get_flash(conn, :error) == "Invalid Request."
    end

    test "with valid params", %{conn: conn} do
      conn = post conn, Routes.pow_assent_registration_path(conn, :create, @provider), @valid_params

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert user.email == "foo@example.com"
      assert get_flash(conn, :info) == "user_created_test_provider"
    end

    test "with taken user id params", %{conn: conn} do
      conn = post conn, Routes.pow_assent_registration_path(conn, :create, @provider), @taken_params

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"taken@example.com\">"
      assert html =~ "<span class=\"help-block\">has already been taken</span>"
    end

    test "with identity already bound to another user", %{conn: conn} do
      params = provider_params(user_identity_params: %{"uid" => "identity_taken"})
      conn   =
        conn
        |> Plug.Conn.put_session(:pow_assent_params, params)
        |> post(Routes.pow_assent_registration_path(conn, :create, @provider), @valid_params)

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :new)
      assert get_flash(conn, :error) == "The Test provider account is already bound to another user."
    end
  end

  alias PowAssent.Test.EmailConfirmation.Phoenix.Endpoint, as: EmailConfirmationEndpoint
  alias PowAssent.Test.EmailConfirmation.Users.User, as: EmailConfirmationUser
  describe "POST /auth/:provider/create with PowEmailConfirmation" do
    @valid_params %{user: %{email: "foo@example.com"}}
    @taken_params %{user: %{email: "taken@example.com"}}

    test "with email from user", %{conn: conn} do
      conn = Phoenix.ConnTest.dispatch(conn, EmailConfirmationEndpoint, :post, Routes.pow_assent_registration_path(conn, :create, @provider), @valid_params)

      refute Pow.Plug.current_user(conn)

      assert redirected_to(conn) == "/registration_created"
      assert get_flash(conn, :error) == "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

      assert user = Process.get({EmailConfirmationUser, :inserted})
      assert user.email == "foo@example.com"
      assert user.email_confirmation_token
      refute user.email_confirmed_at

      assert_received {:mail_mock, mail}
      mail.html =~ "http://example.com/confirm-email/"
    end

    test "with already taken email", %{conn: conn} do
      conn = Phoenix.ConnTest.dispatch(conn, EmailConfirmationEndpoint, :post, Routes.pow_assent_registration_path(conn, :create, @provider), @taken_params)

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"taken@example.com\">"
      assert html =~ "<span class=\"help-block\">has already been taken</span>"
    end
  end

  alias PowAssent.Test.WithAccessToken.Phoenix.Endpoint, as: WithAccessTokenEndpoint
  describe "POST /auth/:provider/create recording strategy params" do
    test "records", %{conn: conn} do
      conn = Phoenix.ConnTest.dispatch(conn, WithAccessTokenEndpoint, :post, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "foo@example.com"}})

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert [user_identity] = user.user_identities
      assert user_identity.access_token == "access_token"
    end
  end
end
