defmodule PowAssent.Phoenix.ViewHelpersTest do
  use PowAssent.Test.Phoenix.ConnCase

  alias Plug.Conn
  alias Phoenix.HTML.{Link, Tag}
  alias PowAssent.Phoenix.ViewHelpers
  alias PowAssent.Test.{Phoenix.Router, Ecto.Users.User, RepoMock}

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

  test "provider_links/2", %{conn: conn} do
    [safe: iodata] = ViewHelpers.provider_links(conn)
    assert {:safe, iodata} == Link.link("Sign in with Test provider", to: "/auth/test_provider/new")

    conn = Pow.Plug.assign_current_user(conn, %User{id: 1}, [])

    [safe: iodata] = ViewHelpers.provider_links(conn)
    assert {:safe, iodata} == Link.link("Remove Test provider authentication", to: "/auth/test_provider", method: "delete")
  end

  test "provider_links/2 with link opts", %{conn: conn} do
    [safe: iodata] = ViewHelpers.provider_links(conn, class: "example")

    assert {:safe, iodata} == Link.link("Sign in with Test provider", to: "/auth/test_provider/new", class: "example")
  end

  test "provider_links/2 with request_path", %{conn: conn} do
    [safe: iodata] =
      conn
      |> Conn.assign(:request_path, "/custom-url")
      |> ViewHelpers.provider_links()

    assert {:safe, iodata} == Link.link("Sign in with Test provider", to: "/auth/test_provider/new?request_path=%2Fcustom-url")
  end

  test "provider_links/2 with invited_user", %{conn: conn} do
    conn = Conn.assign(conn, :invited_user, %PowAssent.Test.Invitation.Users.User{invitation_token: "token"})

    [safe: iodata] = ViewHelpers.provider_links(conn)
    assert {:safe, iodata} == Link.link("Sign in with Test provider", to: "/auth/test_provider/new?invitation_token=token")
  end

  test "provider_links/2 with callback", %{conn: conn} do
    callback =
      fn provider, providers_for_user ->
        case provider in providers_for_user do
          true ->
            ViewHelpers.deauthorization_link(conn, :test_provider, class: "remove") do
              Tag.content_tag(:span, "Provider remove", class: "test_provider")
            end

          false ->
            ViewHelpers.authorization_link(conn, :test_provider, class: "auth") do
              Tag.content_tag(:span, "Provider auth", class: "test_provider")
            end
        end
      end

    [safe: iodata] = ViewHelpers.provider_links(conn, callback)

    assert {:safe, iodata} ==
      (Link.link to: "/auth/test_provider/new", class: "auth" do
        Tag.content_tag(:span, "Provider auth", class: "test_provider")
      end)

    [safe: iodata] =
      conn
      |> Pow.Plug.assign_current_user(%User{id: 1}, [])
      |> ViewHelpers.provider_links(callback)

    assert {:safe, iodata} ==
      (Link.link to: "/auth/test_provider", class: "remove", method: "delete" do
        Tag.content_tag(:span, "Provider remove", class: "test_provider")
      end)
  end

  test "authorization_link/4 accepts blocks", %{conn: conn} do
    {:safe, iodata} = ViewHelpers.authorization_link(conn, :test_provider) do
      "Provider auth"
    end

    assert {:safe, iodata} == Link.link("Provider auth", to: "/auth/test_provider/new")

    {:safe, iodata} = ViewHelpers.authorization_link(conn, :test_provider, class: "example") do
      "Provider auth"
    end

    assert {:safe, iodata} == Link.link("Provider auth", to: "/auth/test_provider/new", class: "example")
  end

  test "deauthorization_link/4 accepts blocks", %{conn: conn} do
    {:safe, iodata} = ViewHelpers.deauthorization_link(conn, :test_provider) do
      "Provider remove"
    end

    assert {:safe, iodata} == Link.link("Provider remove", to: "/auth/test_provider", method: "delete")

    {:safe, iodata} = ViewHelpers.deauthorization_link(conn, :test_provider, class: "example") do
      "Provider remove"
    end

    assert {:safe, iodata} == Link.link("Provider remove", to: "/auth/test_provider", method: "delete", class: "example")
  end
end
