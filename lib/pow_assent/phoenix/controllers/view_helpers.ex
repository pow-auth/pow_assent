# TODO: Remove this when Phoenix 1.7+ is required
if Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
defmodule PowAssent.Phoenix.ViewHelpers do
  @moduledoc false
  alias PowAssent.Plug

  alias Phoenix.{HTML, HTML.Link}
  alias PowAssent.Phoenix.AuthorizationController

  @spec provider_links(Conn.t(), keyword()) :: [HTML.safe()]
  def provider_links(conn, link_opts \\ []) do
    available_providers = Plug.available_providers(conn)
    providers_for_user  = Plug.providers_for_current_user(conn)

    available_providers
    |> Enum.map(&{&1, &1 in providers_for_user})
    |> Enum.map(fn
      {provider, true} -> deauthorization_link(conn, provider, link_opts)
      {provider, false} -> authorization_link(conn, provider, link_opts)
    end)
  end

  @spec authorization_link(Conn.t(), atom(), keyword()) :: HTML.safe()
  def authorization_link(conn, provider, opts \\ []) do
    query_params = invitation_token_query_params(conn) ++ request_path_query_params(conn)

    msg  = AuthorizationController.extension_messages(conn).login_with_provider(%{conn | params: %{"provider" => provider}})
    path = AuthorizationController.routes(conn).path_for(conn, AuthorizationController, :new, [provider], query_params)
    opts = Keyword.merge(opts, to: path)

    Link.link(msg, opts)
  end

  defp invitation_token_query_params(%{assigns: %{invited_user: %{invitation_token: token}}}), do: [invitation_token: token]
  defp invitation_token_query_params(_conn), do: []

  defp request_path_query_params(%{assigns: %{request_path: request_path}}), do: [request_path: request_path]
  defp request_path_query_params(_conn), do: []

  @spec deauthorization_link(Conn.t(), atom(), keyword()) :: HTML.safe()
  def deauthorization_link(conn, provider, opts \\ []) do
    msg  = AuthorizationController.extension_messages(conn).remove_provider_authentication(%{conn | params: %{"provider" => provider}})
    path = AuthorizationController.routes(conn).path_for(conn, AuthorizationController, :delete, [provider])
    opts = Keyword.merge(opts, to: path, method: :delete)

    Link.link(msg, opts)
  end
end
end
