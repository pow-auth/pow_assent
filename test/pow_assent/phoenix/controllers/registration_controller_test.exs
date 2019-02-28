defmodule PowAssent.Phoenix.RegistrationControllerTest do
  use PowAssent.Test.Phoenix.ConnCase

  @provider "test_provider"
  @provider_params %{"uid" => "new_user", "name" => "John Doe"}

  setup %{conn: conn} do
    conn = Plug.Conn.put_session(conn, :pow_assent_params, @provider_params)

    {:ok, conn: conn}
  end

  describe "GET /auth/:provider/add-user-id" do
    test "shows", %{conn: conn} do
      conn = get conn, Routes.pow_assent_registration_path(conn, :add_user_id, @provider)
      assert html_response(conn, 200)
    end

    test "with missing session", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.delete_session(:pow_assent_params)
        |> get(Routes.pow_assent_registration_path(conn, :add_user_id, @provider))

      assert redirected_to(conn) == "/logged-out"
      assert get_flash(conn, :error) == "Invalid Request."
    end
  end

  describe "POST /auth/:provider/create" do
    test "with missing session", %{conn: conn} do
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

    test "with error", %{conn: conn} do
      conn = post conn, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "taken@example.com"}}

      assert html_response(conn, 200) =~ "has already been taken"
    end

    test "with duplicate identity", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_params, %{"uid" => "different_user", "name" => "John Doe"})
        |> post(Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "foo@example.com"}})

      assert redirected_to(conn) == "/logged-out"
      assert get_flash(conn, :error) == "Invalid Request."
    end
  end

  describe "GET /auth/:provider/create with PowEmailConfirmation" do
    test "with user entered email", %{conn: conn} do
      conn = Phoenix.ConnTest.dispatch conn, PowAssent.Test.Phoenix.EndpointConfirmEmail, :post, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "foo@example.com"}}

      assert redirected_to(conn) == "/registration_created"
      assert get_flash(conn, :info) == "user_created_test_provider"

      assert user = Pow.Plug.current_user(conn)
      assert user.email == "foo@example.com"

      assert_received {:mail_mock, mail}
      mail.html =~ "http://example.com/confirm-email/"
    end

    test "with email from provider", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_session(:pow_assent_params, %{"uid" => "new_user", "name" => "John Doe", "email" => "foo@example.com"})
        |> Phoenix.ConnTest.dispatch(PowAssent.Test.Phoenix.EndpointConfirmEmail, :post, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{}})

      assert redirected_to(conn) == "/registration_created"

      refute_received {:mail_mock, _mail}
    end
  end
end
