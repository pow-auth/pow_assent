defmodule PowAssent.Phoenix.ViewHelpers do
  @moduledoc """
  View helpers to render authorization links.
  """
  alias PowAssent.Plug

  alias Phoenix.{HTML, HTML.Link}
  alias PowAssent.Phoenix.AuthorizationController

  @doc """
  Generates list of authorization links for all configured providers.

  The list of providers will be fetched from the PowAssent configuration, and
  `authorization_link/2` will be called on each.

  If a user is assigned to the conn, the authorized providers for a user will
  be looked up with `PowAssent.Plug.providers_for_current_user/1`.
  `deauthorization_link/2` will be used for any already authorized providers.

  The second argument may be link options passed on to `authorization_link/2`
  or `deauthorization_link/2` respectively. It may also be a method that
  handles render callback as seen in the example below.

  ## Example

      ViewHelpers.provider_links @conn, fn provider, providers_for_user ->
        if provider in providers_for_user do
          ViewHelpers.deauthorization_link @conn, provider do
            Tag.content_tag(:span, "Remove \#{provider}", class: provider)
          end
        else
          ViewHelpers.authorization_link @conn, provider do
            Tag.content_tag(:span, "Sign in with \#{provider}", class: provider)
          end
        end
      end
  """
  @spec provider_links(Conn.t(), keyword() | ({atom(), boolean()} -> Phoenix.HTML.unsafe())) :: [HTML.safe()]
  def provider_links(conn, link_opts_or_callback \\ []) do
    providers_for_user = Plug.providers_for_current_user(conn)
    callback           = render_callback(link_opts_or_callback, conn)

    conn
    |> Plug.available_providers()
    |> Enum.map(&callback.(&1, providers_for_user))
  end

  defp render_callback(callback, _conn) when is_function(callback), do: callback
  defp render_callback(link_opts, conn) do
    fn provider, providers_for_user ->
      case provider in providers_for_user do
        true  -> deauthorization_link(conn, provider, link_opts)
        false -> authorization_link(conn, provider, link_opts)
      end
    end
  end

  @doc """
  Generates an authorization link for a provider.

  The link is used to sign up or register a user using a provider. If
  `:invited_user` is assigned to the conn, the invitation token will be passed
  on through the URL query params.
  """
  @spec authorization_link(Conn.t(), atom(), keyword(), keyword()) :: HTML.safe()
  def authorization_link(conn, provider, opts \\ [])
  def authorization_link(conn, provider, do: contents),
    do: authorization_link(conn, provider, contents, [])
  def authorization_link(conn, provider, opts) do
    msg = AuthorizationController.extension_messages(conn).login_with_provider(%{conn | params: %{"provider" => provider}})

    authorization_link(conn, provider, msg, opts)
  end
  def authorization_link(conn, provider, opts, do: contents),
    do: authorization_link(conn, provider, contents, opts)
  def authorization_link(conn, provider, contents, opts) do
    query_params = invitation_token_query_params(conn) ++ request_path_query_params(conn)

    path = AuthorizationController.routes(conn).path_for(conn, AuthorizationController, :new, [provider], query_params)
    opts = Keyword.merge(opts, to: path)

    Link.link(contents, opts)
  end

  defp invitation_token_query_params(%{assigns: %{invited_user: %{invitation_token: token}}}), do: [invitation_token: token]
  defp invitation_token_query_params(_conn), do: []

  defp request_path_query_params(%{assigns: %{request_path: request_path}}), do: [request_path: request_path]
  defp request_path_query_params(_conn), do: []

  @doc """
  Generates a provider deauthorization link.

  The link is used to remove authorization with the provider.
  """
  @spec deauthorization_link(Conn.t(), atom(), keyword()) :: HTML.safe()
  def deauthorization_link(conn, provider, opts \\ [])
  def deauthorization_link(conn, provider, do: contents),
    do: deauthorization_link(conn, provider, contents, [])
  def deauthorization_link(conn, provider, opts) do
    msg = AuthorizationController.extension_messages(conn).remove_provider_authentication(%{conn | params: %{"provider" => provider}})

    deauthorization_link(conn, provider, msg, opts)
  end
  def deauthorization_link(conn, provider, opts, do: contents),
    do: deauthorization_link(conn, provider, contents, opts)
  def deauthorization_link(conn, provider, contents, opts) do
    path = AuthorizationController.routes(conn).path_for(conn, AuthorizationController, :delete, [provider])
    opts = Keyword.merge(opts, to: path, method: :delete)

    Link.link(contents, opts)
  end
end
