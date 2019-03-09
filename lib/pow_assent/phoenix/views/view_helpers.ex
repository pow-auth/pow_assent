defmodule PowAssent.Phoenix.ViewHelpers do
  @moduledoc """
  View helpers to render authorization links.
  """
  alias PowAssent.Plug

  alias Phoenix.{HTML, HTML.Link}
  alias PowAssent.Phoenix.AuthorizationController

  @doc """
  Generates list of provider links.
  """
  @spec provider_links(Conn.t()) :: [HTML.safe()]
  def provider_links(conn) do
    providers_for_user = Plug.providers_for_current_user(conn)

    conn
    |> Plug.available_providers()
    |> Enum.map(&provider_link(conn, &1, providers_for_user))
  end

  @doc """
  Generates a provider link.

  If the user is signed in, and has a provider, it'll link to removal of the
  provider authorization.
  """
  @spec provider_link(Conn.t(), atom(), [atom()]) :: HTML.safe()
  def provider_link(conn, provider, providers_for_user) do
    case Enum.member?(providers_for_user, provider) do
      false -> oauth_signin_link(conn, provider)
      true  -> oauth_remove_link(conn, provider)
    end
  end

  defp oauth_signin_link(%{assigns: %{invited_user: %{invitation_token: token}}} = conn, provider) when not is_nil(token) do
    do_oauth_signin_link(conn, provider, invitation_token: token)
  end
  defp oauth_signin_link(conn, provider), do: do_oauth_signin_link(conn, provider)

  defp do_oauth_signin_link(conn, provider, query_params \\[]) do
    msg  = AuthorizationController.messages(conn).login_with_provider(%{conn | params: %{"provider" => provider}})
    path = AuthorizationController.routes(conn).path_for(conn, AuthorizationController, :new, [provider], query_params)

    Link.link(msg, to: path)
  end

  defp oauth_remove_link(conn, provider) do
    msg  = AuthorizationController.messages(conn).remove_provider_authentication(%{conn | params: %{"provider" => provider}})
    path = AuthorizationController.routes(conn).path_for(conn, AuthorizationController, :delete, [provider])

    Link.link(msg, to: path, method: :delete)
  end
end
