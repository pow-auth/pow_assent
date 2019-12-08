defmodule PowAssent.Phoenix.RegistrationControllerTest do
  use PowAssent.Test.Phoenix.ConnCase

  @provider "test_provider"
  @token_params %{"access_token" => "access_token"}
  @user_identity_params %{"provider" => @provider, "uid" => "new_user", "token" => @token_params}
  @user_params %{"name" => "John Doe"}
  @provider_params %{@provider => %{user_identity: @user_identity_params, user: @user_params}}

  setup %{conn: conn} do
    conn = Plug.Conn.put_session(conn, :pow_assent_params, @provider_params)

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
      conn = get(conn, Routes.pow_assent_registration_path(conn, :add_user_id, "invalid"))

      assert redirected_to(conn) == "/logged-out"
      assert get_flash(conn, :error) == "Invalid Request."
    end

    test "shows", %{conn: conn} do
      conn = get conn, Routes.pow_assent_registration_path(conn, :add_user_id, @provider)

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\">"
    end

    test "shows with prefill user id", %{conn: conn} do
      provider_params = %{@provider => %{user_identity: @user_identity_params, user: Map.put(@user_params, "email", "taken@example.com")}}
      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_params, provider_params)
        |> get(Routes.pow_assent_registration_path(conn, :add_user_id, @provider))

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"taken@example.com\">"
    end
  end

  describe "POST /auth/:provider/create" do
    test "with missing session params", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.delete_session(:pow_assent_params)
        |> post(Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "foo@example.com"}})

      assert redirected_to(conn) == "/logged-out"
      assert get_flash(conn, :error) == "Invalid Request."
    end

    test "with valid params", %{conn: conn} do
      conn = post conn, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "foo@example.com"}}

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert user.email == "foo@example.com"
      assert get_flash(conn, :info) == "user_created_test_provider"
    end

    test "with invalid params", %{conn: conn} do
      conn = post conn, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "taken@example.com"}}

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"taken@example.com\">"
      assert html =~ "<span class=\"help-block\">has already been taken</span>"
    end

    test "with identity already bound to another user", %{conn: conn} do
      params = %{@provider => %{user_identity: %{"provider" => @provider, "uid" => "identity_taken", "token" => @token_params}, user: %{"name" => "John Doe"}}}
      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_params, params)
        |> post(Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "foo@example.com"}})

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :new)
      assert get_flash(conn, :error) == "The Test provider account is already bound to another user."
    end
  end

  alias PowAssent.Test.EmailConfirmation.Phoenix.Endpoint, as: EmailConfirmationEndpoint
  describe "GET /auth/:provider/create with PowEmailConfirmation" do
    test "with user email", %{conn: conn} do
      params = %{@provider => %{user_identity: %{"provider" => @provider, "uid" => "new_user", "token" => @token_params}, user: %{}}}
      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_params, params)
        |> Phoenix.ConnTest.dispatch(EmailConfirmationEndpoint, :post, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "foo@example.com"}})

      refute Pow.Plug.current_user(conn)

      assert redirected_to(conn) == "/registration_created"
      assert get_flash(conn, :error) == "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

      assert_received {:mail_mock, mail}
      mail.html =~ "http://example.com/confirm-email/"
    end

    test "with provider email", %{conn: conn} do
      params = %{@provider => %{user_identity: %{"provider" => @provider, "uid" => "new_user", "token" => @token_params}, user: %{"name" => "John Doe", "email" => "foo@example.com"}}}
      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_params, params)
        |> Phoenix.ConnTest.dispatch(EmailConfirmationEndpoint, :post, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{}})

      refute Pow.Plug.current_user(conn)

      assert redirected_to(conn) == "/registration_created"
      assert get_flash(conn, :error) == "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

      assert_received {:mail_mock, mail}
      mail.html =~ "http://example.com/confirm-email/"
    end

    test "with verified provider email", %{conn: conn} do
      params = %{@provider => %{user_identity: %{"provider" => @provider, "uid" => "new_user", "token" => @token_params}, user: %{"name" => "John Doe", "email" => "foo@example.com", "email_verified" => true}}}
      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_params, params)
        |> Phoenix.ConnTest.dispatch(EmailConfirmationEndpoint, :post, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{}})

      assert redirected_to(conn) == "/registration_created"
      assert Pow.Plug.current_user(conn)

      refute_received {:mail_mock, _mail}
    end
  end

  describe "POST /auth/:provider/create recording strategy params" do
    setup %{conn: conn} do
      user_identity_params = %{"provider" => @provider, "uid" => "new_user_with_access_token", "token" => @token_params}
      provider_params      = %{@provider => %{user_identity: user_identity_params, user: @user_params}}
      conn                 = Plug.Conn.put_session(conn, :pow_assent_params, provider_params)

      {:ok, conn: conn}
    end

    test "records", %{conn: conn} do
      conn = post conn, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "foo@example.com"}}

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert [user_identity] = user.user_identities
      assert user_identity.access_token == "access_token"
    end
  end
end
