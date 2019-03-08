defmodule PowAssent.Phoenix.RegistrationControllerTest do
  use PowAssent.Test.Phoenix.ConnCase

  @provider "test_provider"
  @provider_params %{"uid" => "new_user", "name" => "John Doe"}

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

    test "shows", %{conn: conn} do
      conn = get conn, Routes.pow_assent_registration_path(conn, :add_user_id, @provider)

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\">"
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
      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_params, %{"uid" => "different_user", "name" => "John Doe"})
        |> post(Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "foo@example.com"}})

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :new)
      assert get_flash(conn, :error) == "The Test provider account is already bound to another user."
    end
  end

  alias PowAssent.Test.Phoenix.EndpointConfirmEmail
  describe "GET /auth/:provider/create with PowEmailConfirmation" do
    test "with user email", %{conn: conn} do
      conn = Phoenix.ConnTest.dispatch conn, EndpointConfirmEmail, :post, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "foo@example.com"}}

      assert redirected_to(conn) == "/registration_created"
      assert get_flash(conn, :info) == "user_created_test_provider"

      assert user = Pow.Plug.current_user(conn)
      assert user.email == "foo@example.com"
      assert user.email_confirmation_token

      assert_received {:mail_mock, mail}
      mail.html =~ "http://example.com/confirm-email/"
    end

    test "with provider email", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_params, %{"uid" => "new_user", "name" => "John Doe", "email" => "foo@example.com"})
        |> Phoenix.ConnTest.dispatch(EndpointConfirmEmail, :post, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{}})

      assert redirected_to(conn) == "/registration_created"
      assert Pow.Plug.current_user(conn)

      refute_received {:mail_mock, _mail}
    end
  end
end
