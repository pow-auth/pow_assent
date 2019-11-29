defmodule PowAssent.ViewHelpersTest do
  use PowAssent.Test.Phoenix.ConnCase

  alias Plug.Conn
  alias Phoenix.HTML.Link
  alias PowAssent.Phoenix.ViewHelpers
  alias PowAssent.Test.{Phoenix.Router, UserIdentitiesMock}

  setup %{conn: conn} do
    config = [
      pow_assent: [
        user_identities_context: UserIdentitiesMock,
        providers: [
          test_provider: [
            strategy: TestProvider
          ]
        ]
      ]
    ]

    conn =
      conn
      |> Conn.put_private(:pow_config, config)
      |> Conn.put_private(:phoenix_router, Router)

    {:ok, conn: conn}
  end

  test "provider_links/1", %{conn: conn} do
    [safe: iodata] = ViewHelpers.provider_links(conn)
    assert {:safe, iodata} == Link.link("Sign in with Test provider", to: "/auth/test_provider/new")

    conn = Pow.Plug.assign_current_user(conn, UserIdentitiesMock.user(), [])

    [safe: iodata] = ViewHelpers.provider_links(conn)
    assert {:safe, iodata} == Link.link("Remove Test provider authentication", to: "/auth/test_provider", method: "delete")
  end

  test "provider_links/1 with link opts", %{conn: conn} do
    [safe: iodata] = ViewHelpers.provider_links(conn, class: "example")

    assert {:safe, iodata} == Link.link("Sign in with Test provider", to: "/auth/test_provider/new", class: "example")
  end

  test "provider_links/1 with request_path", %{conn: conn} do
    [safe: iodata] =
      conn
      |> Conn.assign(:request_path, "/custom-url")
      |> ViewHelpers.provider_links()

    assert {:safe, iodata} == Link.link("Sign in with Test provider", to: "/auth/test_provider/new?request_path=%2Fcustom-url")
  end

  test "provider_links/1 with invited_user", %{conn: conn} do
    conn = PowInvitation.Plug.assign_invited_user(conn, %PowAssent.Test.Invitation.Users.User{invitation_token: "token"})

    [safe: iodata] = ViewHelpers.provider_links(conn)
    assert {:safe, iodata} == Link.link("Sign in with Test provider", to: "/auth/test_provider/new?invitation_token=token")
  end
end
