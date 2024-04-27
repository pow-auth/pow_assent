defmodule PowAssent.Phoenix.HTML.CoreComponentsTest do
  use PowAssent.Test.Phoenix.ConnCase
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias Plug.Conn
  alias PowAssent.Phoenix.HTML.CoreComponents
  alias PowAssent.Test.{Ecto.Users.User, Phoenix.Router, RepoMock}

  setup %{conn: conn} do
    config = [
      repo: RepoMock,
      pow_assent: [
        providers: [
          test_provider: [
            strategy: TestProvider
          ],
          other_provider: [
            strategy: OtherProvider
          ]
        ]
      ]
    ]

    conn =
      conn
      |> Conn.put_private(:pow_config, config)
      |> Conn.put_private(:phoenix_router, Router)
      |> Pow.Plug.assign_current_user(%User{id: 1}, [])

    {:ok, conn: conn}
  end

  test "provider_links/1", %{conn: conn} do
    template = fn assigns ->
      ~H"""
      <CoreComponents.provider_links conn={@conn} />
      """
    end

    expected = fn assigns ->
      ~H"""
      <.link href={"/auth/test_provider"} method="delete">
        Remove Test provider authentication
      </.link><.link navigate={"/auth/other_provider/new"}>
        Sign in with Other provider
      </.link>
      """
    end

    assert render_component(&template.(&1), %{conn: conn}) ==
      render_component(&expected.(&1))
  end

  test "provider_links/1 with slot assigns", %{conn: conn} do
    template =
      fn assigns ->
        ~H"""
        <CoreComponents.provider_links conn={@conn}>
          <:authorization_link class="auth" />
          <:deauthorization_link class="deauth" />
        </CoreComponents.provider_links>
        """
      end

    expected = fn assigns ->
      ~H"""
      <.link href={"/auth/test_provider"} method="delete" class="deauth">
        Remove Test provider authentication
      </.link><.link navigate={"/auth/other_provider/new"} class="auth">
        Sign in with Other provider
      </.link>
      """
    end

    assert render_component(&template.(&1), %{conn: conn}) ==
      render_component(&expected.(&1))
  end

  test "provider_links/1 with slot inner block", %{conn: conn} do
    template =
      fn assigns ->
        ~H"""
        <CoreComponents.provider_links conn={@conn}>
          <:authorization_link>Authorization</:authorization_link>
          <:deauthorization_link>Deauthorization</:deauthorization_link>
        </CoreComponents.provider_links>
        """
      end

    expected = fn assigns ->
      ~H"""
      <.link href={"/auth/test_provider"} method="delete">
        Deauthorization
      </.link><.link navigate={"/auth/other_provider/new"}>
        Authorization
      </.link>
      """
    end

    assert render_component(&template.(&1), %{conn: conn}) ==
      render_component(&expected.(&1))
  end

  test "provider_links/1 with request_path", %{conn: conn} do
    conn = Conn.assign(conn, :request_path, "/custom-url")

    template = fn assigns ->
      ~H"""
      <CoreComponents.provider_links conn={@conn} />
      """
    end

    expected = fn assigns ->
      ~H"""
      <.link href={"/auth/test_provider"} method="delete">
        Remove Test provider authentication
      </.link><.link navigate={"/auth/other_provider/new?request_path=%2Fcustom-url"}>
        Sign in with Other provider
      </.link>
      """
    end

    assert render_component(&template.(&1), %{conn: conn}) ==
      render_component(&expected.(&1))
  end

  test "provider_links/1 with invited_user", %{conn: conn} do
    conn = Conn.assign(conn, :invited_user, %PowAssent.Test.Invitation.Users.User{invitation_token: "token"})

    template = fn assigns ->
      ~H"""
      <CoreComponents.provider_links conn={@conn} />
      """
    end

    expected = fn assigns ->
      ~H"""
      <.link href={"/auth/test_provider"} method="delete">
        Remove Test provider authentication
      </.link><.link navigate={"/auth/other_provider/new?invitation_token=token"}>
        Sign in with Other provider
      </.link>
      """
    end

    assert render_component(&template.(&1), %{conn: conn}) ==
      render_component(&expected.(&1))
  end

  test "authorization_link/1 with assigns", %{conn: conn} do
    template = fn assigns ->
      ~H"""
      <CoreComponents.authorization_link conn={@conn} provider="my_provider" class="example" />
      """
    end

    expected = fn assigns ->
      ~H"""
      <.link navigate={"/auth/my_provider/new"} class="example">Sign in with My provider</.link>
      """
    end

    assert render_component(&template.(&1), %{conn: conn}) ==
      render_component(&expected.(&1))
  end

  test "authorization_link/1 with inner block", %{conn: conn} do
   template = fn assigns ->
      ~H"""
      <CoreComponents.authorization_link conn={@conn} provider="my_provider">
        Authorize
      </CoreComponents.authorization_link>
      """
    end

    expected = fn assigns ->
      ~H"""
      <.link navigate={"/auth/my_provider/new"}>
        Authorize
      </.link>
      """
    end

    assert render_component(&template.(&1), %{conn: conn}) ==
      render_component(&expected.(&1))
  end

  test "deauthorization_link/1 with assigns", %{conn: conn} do
    template = fn assigns ->
      ~H"""
      <CoreComponents.deauthorization_link conn={@conn} provider="my_provider" class="example" />
      """
    end

    expected = fn assigns ->
      ~H"""
      <.link href={"/auth/my_provider"} method="delete" class="example">Remove My provider authentication</.link>
      """
    end

    assert render_component(&template.(&1), %{conn: conn}) ==
      render_component(&expected.(&1))
  end

  test "deauthorization_link/1 with inner block", %{conn: conn} do
   template = fn assigns ->
      ~H"""
      <CoreComponents.deauthorization_link conn={@conn} provider="my_provider">
        Deauthorize
      </CoreComponents.deauthorization_link>
      """
    end

    expected = fn assigns ->
      ~H"""
      <.link href={"/auth/my_provider"} method="delete">
        Deauthorize
      </.link>
      """
    end

    assert render_component(&template.(&1), %{conn: conn}) ==
      render_component(&expected.(&1))
  end
end
