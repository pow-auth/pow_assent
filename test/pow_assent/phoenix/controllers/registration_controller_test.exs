defmodule PowAssent.Phoenix.RegistrationControllerTest do
  use PowAssent.Test.Phoenix.ConnCase

  alias Plug.Conn

  @provider "test_provider"
  @token_params %{"access_token" => "access_token"}
  @user_identity_params %{"provider" => @provider, "uid" => "new_user", "token" => @token_params}
  @user_params %{"name" => "John Doe"}

  setup %{conn: conn} do
    conn = Conn.put_private(conn, :pow_assent_session, %{callback_params: provider_params()})

    {:ok, conn: conn}
  end

  describe "GET /auth/:provider/add-user-id" do
    test "with missing session params", %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_assent_session, nil)
        |> get(Routes.pow_assent_registration_path(conn, :add_user_id, @provider))

      refute conn.private[:plug_session]["pow_assent_session"]
      assert redirected_to(conn) == "/logged-out"
      assert get_flash(conn, :error) == "Invalid Request."
    end

    test "with invalid provider path", %{conn: conn} do
      conn = get conn, Routes.pow_assent_registration_path(conn, :add_user_id, "invalid")

      refute conn.private[:plug_session]["pow_assent_session"]
      assert redirected_to(conn) == "/logged-out"
      assert get_flash(conn, :error) == "Invalid Request."
    end

    test "shows", %{conn: conn} do
      conn = get conn, Routes.pow_assent_registration_path(conn, :add_user_id, @provider)

      assert conn.private[:plug_session]["pow_assent_session"]
      assert conn.private[:pow_assent_session][:callback_params] == provider_params()
      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\">"
    end

    test "shows with changeset stored in session", %{conn: conn} do
      {:error, {:invalid_user_id_field, changeset}} = PowAssent.Ecto.UserIdentities.Context.create_user(@user_identity_params, Map.put(@user_params, "email", "taken@example.com"), nil, repo: PowAssent.Test.RepoMock, user: PowAssent.Test.Ecto.Users.User)
      conn =
        conn
        |> Conn.put_private(:pow_assent_session, %{changeset: changeset, callback_params: provider_params()})
        |> get(Routes.pow_assent_registration_path(conn, :add_user_id, @provider))

      assert conn.private[:plug_session]["pow_assent_session"]
      assert conn.private[:pow_assent_session][:callback_params] == provider_params()
      refute conn.private[:pow_assent_session][:changeset]
      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"taken@example.com\">"
      assert html =~ "<span class=\"help-block\">has already been taken</span>"
    end
  end

  describe "POST /auth/:provider/create" do
    @valid_params %{user: %{email: "foo@example.com"}}
    @taken_params %{user: %{email: "taken@example.com"}}

    test "with missing session params", %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_assent_session, nil)
        |> post(Routes.pow_assent_registration_path(conn, :create, @provider), @valid_params)

      refute conn.private[:plug_session]["pow_assent_session"]
      refute conn.private[:pow_assent_session][:callback_params]
      assert redirected_to(conn) == "/logged-out"
      assert get_flash(conn, :error) == "Invalid Request."
    end

    test "with valid params", %{conn: conn} do
      conn = post conn, Routes.pow_assent_registration_path(conn, :create, @provider), @valid_params

      refute conn.private[:plug_session]["pow_assent_session"]
      refute conn.private[:pow_assent_session][:callback_params]
      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert user.email == "foo@example.com"
      assert get_flash(conn, :info) == "user_created_test_provider"
    end

    test "with taken user id params", %{conn: conn} do
      conn = post conn, Routes.pow_assent_registration_path(conn, :create, @provider), @taken_params

      assert conn.private[:plug_session]["pow_assent_session"]
      assert conn.private[:pow_assent_session][:callback_params] == provider_params()
      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"taken@example.com\">"
      assert html =~ "<span class=\"help-block\">has already been taken</span>"
    end

    test "with identity already bound to another user", %{conn: conn} do
      params = provider_params(user_identity_params: %{"uid" => "identity_taken"})
      conn   =
        conn
        |> Conn.put_private(:pow_assent_session, %{callback_params: params})
        |> post(Routes.pow_assent_registration_path(conn, :create, @provider), @valid_params)

      refute conn.private[:plug_session]["pow_assent_session"]
      refute conn.private[:pow_assent_session][:callback_params]
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

      refute conn.private[:plug_session]["pow_assent_session"]
      refute conn.private[:pow_assent_session][:callback_params]

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

    test "with taken email", %{conn: conn} do
      conn = Phoenix.ConnTest.dispatch(conn, EmailConfirmationEndpoint, :post, Routes.pow_assent_registration_path(conn, :create, @provider), @taken_params)

      refute conn.private[:plug_session]["pow_assent_session"]
      refute conn.private[:pow_assent_session][:callback_params]

      refute Pow.Plug.current_user(conn)

      assert redirected_to(conn) == "/registration_created"
      assert get_flash(conn, :error) == "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

      refute_received {:mail_mock, _mail}
    end
  end

  alias PowAssent.Test.WithAccessToken.Phoenix.Endpoint, as: WithAccessTokenEndpoint
  describe "POST /auth/:provider/create recording strategy params" do
    test "records", %{conn: conn} do
      conn = Phoenix.ConnTest.dispatch(conn, WithAccessTokenEndpoint, :post, Routes.pow_assent_registration_path(conn, :create, @provider), %{user: %{email: "foo@example.com"}})

      refute conn.private[:plug_session]["pow_assent_session"]
      refute conn.private[:pow_assent_session][:callback_params]

      assert redirected_to(conn) == "/registration_created"
      assert user = Pow.Plug.current_user(conn)
      assert [user_identity] = user.user_identities
      assert user_identity.access_token == "access_token"
    end
  end

  defp provider_params(opts \\ []) do
    user_identity_params = Map.merge(@user_identity_params, Keyword.get(opts, :user_identity_params, %{}))
    user_params = Map.merge(@user_params, Keyword.get(opts, :user_params, %{}))

    %{@provider => %{user_identity: user_identity_params, user: user_params}}
  end
end
