# TODO: Remove conditional when LiveView for Phoenix 1.7+ is required
# Credo will complain about unless statement but we want this first
# credo:disable-for-next-line
unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
defmodule PowAssent.Phoenix.HTML.CoreComponents do
  @moduledoc false
  use Phoenix.Component

  alias PowAssent.{Phoenix.AuthorizationController, Plug}

  @doc """
  Renders a list of authorization links for all configured providers.

  The list of providers will be fetched from the PowAssent configuration, and
  `authorization_link/1` will be called on each.

  If a user is assigned to the conn, the authorized providers for a user will
  be looked up with `PowAssent.Plug.providers_for_current_user/1`.
  `deauthorization_link/1` will be used for any already authorized providers.

  ## Examples

      <.provider_links conn={@conn} />

      <.provider_links conn={@conn}>
        <:authorization_link class="text-green-500">
          Sign in with <%= @provider %>
        <:/authorization_link>

        <:deauthorization_link class="text-red-500">
          Remove <%= @provider %> authentication
        <:/deauthorization_link>
      </.provider_links>
  """
  attr :conn, :any, required: true, doc: "the conn"

  slot :authorization_link, doc: "attributes and inner content for the authorization link" do
    attr :class, :string, doc: "Additional classes added to the `.link` tag"
  end

  slot :deauthorization_link, doc: "attributes and inner content for the deuathorization link" do
    attr :class, :string, doc: "Additional classes added to the `.link` tag"
  end

  def provider_links(assigns) do
    providers = Plug.available_providers(assigns.conn)
    providers_for_user = Plug.providers_for_current_user(assigns.conn)

    assigns =
      assign(
        assigns,
        class: %{
          authorization: (for %{class: class} <- assigns.authorization_link, do: class),
          deauthorization: (for %{class: class} <- assigns.deauthorization_link, do: class)
        },
        label: %{
          authorization: Enum.reject(assigns.authorization_link, &is_nil(&1.inner_block)),
          deauthorization: Enum.reject(assigns.deauthorization_link, &is_nil(&1.inner_block))
        },
        providers: providers,
        providers_for_user: providers_for_user
      )

    ~H"""
    <%= for provider <- @providers do %><.authorization_link
        :if={provider not in @providers_for_user}
        conn={@conn}
        provider={provider}
        {@class.authorization != [] && [class: @class.authorization] || []}
      >
      <%= @label.authorization != [] && render_slot(@label.authorization, provider) || sign_in_with_provider_label(@conn, provider) %>
    </.authorization_link><.deauthorization_link
        :if={provider in @providers_for_user}
        conn={@conn}
        provider={provider}
        {@class.deauthorization != [] && [class: @class.deauthorization] || []}
     >
      <%= @label.deauthorization != [] && render_slot(@label.deauthorization, provider) || remove_provider_authentication_label(@conn, provider) %>
    </.deauthorization_link><% end %>
    """
  end

  defp sign_in_with_provider_label(conn, provider) do
    AuthorizationController.extension_messages(conn).login_with_provider(%{conn | params: %{"provider" => provider}})
  end

  defp remove_provider_authentication_label(conn, provider) do
    AuthorizationController.extension_messages(conn).remove_provider_authentication(%{conn | params: %{"provider" => provider}})
  end

  @doc """
  Renders an authorization link for a provider.

  The link is used to sign up or register a user using a provider. If
  `:invited_user` is assigned to the conn, the invitation token will be passed
  on through the URL query params.

  ## Examples

      <.authorization_link conn={@conn} provider="github" />

      <.authorization_link conn={@conn} provider="github">Sign in with Github</.authorization_link>
  """
  attr :conn, :any, required: true, doc: "the conn"
  attr :provider, :any, required: true, doc: "the provider"

  attr :rest,
    :global,
    include: ~w(csrf_token download hreflang referrerpolicy rel target type),
    doc: "
    Additional attributes added to the `.link` tag.
    "

  slot :inner_block

  def authorization_link(assigns) do
    query_params = invitation_token_query_params(assigns.conn) ++ request_path_query_params(assigns.conn)
    path = AuthorizationController.routes(assigns.conn).path_for(assigns.conn, AuthorizationController, :new, [assigns.provider], query_params)
    assigns = assign(assigns, navigate: path)

    ~H"""
    <.link navigate={@navigate} {@rest}><%= render_slot(@inner_block) || sign_in_with_provider_label(@conn, @provider) %></.link>
    """
  end

  defp invitation_token_query_params(%{assigns: %{invited_user: %{invitation_token: token}}}), do: [invitation_token: token]
  defp invitation_token_query_params(_conn), do: []

  defp request_path_query_params(%{assigns: %{request_path: request_path}}), do: [request_path: request_path]
  defp request_path_query_params(_conn), do: []

  @doc """
  Renders a deauthorization link for a provider.

  The link is used to remove authorization with the provider.

  ## Examples

      <.deauthorization_link conn={@conn} provider="github">

      <.deauthorization_link conn={@conn} provider="github">Remove Github authentication</.deauthorization_link>
  """
  attr :conn, :any, required: true, doc: "the conn"
  attr :provider, :any, required: true, doc: "the provider"

  attr :rest,
    :global,
    include: ~w(csrf_token download hreflang referrerpolicy rel target type),
    doc: "Additional attributes added to the `.link` tag."

  slot :inner_block

  def deauthorization_link(assigns) do
    path = AuthorizationController.routes(assigns.conn).path_for(assigns.conn, AuthorizationController, :delete, [assigns.provider])
    assigns = assign(assigns, navigate: path)

    ~H"""
    <.link href={@navigate} method="delete" {@rest}><%= render_slot(@inner_block) || remove_provider_authentication_label(@conn, @provider) %></.link>
    """
  end
end
end
