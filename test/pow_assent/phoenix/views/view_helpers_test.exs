defmodule PowAssent.ViewHelpersTest do
  use PowAssent.Test.Phoenix.ConnCase

  alias Plug.Conn
  alias Phoenix.HTML.Link
  alias PowAssent.Phoenix.ViewHelpers
  alias PowAssent.Test.Ecto.Users.User

  setup %{conn: conn} do
    config = [
      repo: PowAssent.Test.Phoenix.MockRepo,
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
      |> Conn.put_private(:phoenix_router, PowAssent.Test.Phoenix.Router)

    {:ok, conn: conn}
  end

  test "provider_links/1", %{conn: conn} do
    [safe: iodata] = ViewHelpers.provider_links(conn)
    assert {:safe, iodata} == Link.link("Sign in with Test provider", to: "/auth/test_provider/new")

    conn = Pow.Plug.assign_current_user(conn, %User{id: 1}, [])

    [safe: iodata] = ViewHelpers.provider_links(conn)
    assert {:safe, iodata} == Link.link("Remove Test provider authentication", to: "/auth/test_provider", method: "delete")
  end
end
