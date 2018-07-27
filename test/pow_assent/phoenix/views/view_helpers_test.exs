defmodule PowAssent.ViewHelpersTest do
  use PowAssent.Test.Phoenix.ConnCase

  alias Phoenix.HTML.Link
  alias PowAssent.Phoenix.ViewHelpers
  alias PowAssent.Test.Ecto.Users.User

  setup %{conn: conn} do
    Application.put_env(:pow_assent, :pow_assent,
      providers: [
        test_provider: [
          strategy: TestProvider
        ]])

    conn = get(conn, Routes.pow_assent_authorization_path(conn, :new, "test_provider"))

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
