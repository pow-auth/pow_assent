defmodule PowAssent.ViewHelpersTest do
  use PowAssent.Test.Phoenix.ConnCase

  alias Phoenix.HTML.Link
  alias Plug.Conn
  alias PowAssent.Phoenix.ViewHelpers
  alias PowAssent.Test.{Ecto.Users.User, Phoenix.Router, RepoMock}

  setup %{conn: conn} do
    config = [
      repo: RepoMock,
      pow_assent: [
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

    conn = Pow.Plug.assign_current_user(conn, %User{id: 1}, [])

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
    conn = Conn.assign(conn, :invited_user, %PowAssent.Test.Invitation.Users.User{invitation_token: "token"})

    [safe: iodata] = ViewHelpers.provider_links(conn)
    assert {:safe, iodata} == Link.link("Sign in with Test provider", to: "/auth/test_provider/new?invitation_token=token")
  end
end
