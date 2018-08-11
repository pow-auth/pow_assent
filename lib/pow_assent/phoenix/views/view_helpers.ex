defmodule PowAssent.Phoenix.ViewHelpers do
  @moduledoc """
  View helpers to render authorization links.

  ## Usage

      ViewHelpers.provider_links(conn)
  """

  alias PowAssent.Plug

  alias Pow.Phoenix.Controller
  alias PowAssent.Phoenix.RegistrationController
  alias Phoenix.{HTML, HTML.Link}

  def provider_links(conn) do
    providers_for_user = Plug.providers_for_current_user(conn)

    conn
    |> Plug.available_providers()
    |> Enum.map(&provider_link(conn, &1, providers_for_user))
  end

  @spec provider_link(Conn.t(), atom(), [atom()]) :: HTML.safe()
  def provider_link(conn, provider, providers_for_user) do
    case Enum.member?(providers_for_user, provider) do
      false -> oauth_signin_link(conn, provider)
      true  -> oauth_remove_link(conn, provider)
    end
  end

  defp oauth_signin_link(conn, provider) do
    msg  = RegistrationController.messages(conn).login_with_provider(%{conn | params: %{"provider" => provider}})
    path = Controller.router_helpers(conn).pow_assent_authorization_path(conn, :new, provider)

    Link.link(msg, to: path)
  end

  defp oauth_remove_link(conn, provider) do
    msg  = RegistrationController.messages(conn).remove_provider_authentication(%{conn | params: %{"provider" => provider}})
    path = Controller.router_helpers(conn).pow_assent_authorization_path(conn, :delete, provider)

    Link.link(msg, to: path, method: :delete)
  end
end
