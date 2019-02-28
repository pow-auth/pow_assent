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
end
