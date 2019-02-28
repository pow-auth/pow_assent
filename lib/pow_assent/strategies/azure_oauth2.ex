defmodule PowAssent.Strategy.AzureOAuth2 do
  @moduledoc """
  Azure AD OAuth 2.0 strategy.

  ## Usage

      config :my_app, :pow_assent,
        providers: [
          azure: [
            client_id: "REPLACE_WITH_CLIENT_ID",
            client_secret: "REPLACE_WITH_CLIENT_SECRET",
            strategy: PowAssent.Strategy.AzureOAuth2
          ]
        ]

  A tenant id can be set to limit scope of users who can get access (defaults
  to "common"):

      config :my_app, :pow_assent,
        providers: [
          azure: [
            client_id: "REPLACE_WITH_CLIENT_ID",
            client_secret: "REPLACE_WITH_CLIENT_SECRET",
            tenant_id: "8eaef023-2b34-4da1-9baa-8bc8c9d6a490",
            strategy: PowAssent.Strategy.AzureOAuth2,
          ]
        ]

  The resource that client should pull a token for defaults to
  `https://graph.microsoft.com/`. It can be overridden with the
  `resource` key (or the `authorization_params` key):

      config :my_app, :pow_assent,
        providers: [
          azure: [
            client_id: "REPLACE_WITH_CLIENT_ID",
            client_secret: "REPLACE_WITH_CLIENT_SECRET",
            tenant_id: "8eaef023-2b34-4da1-9baa-8bc8c9d6a490",
            resource: "https://service.contoso.com/",
            strategy: PowAssent.Strategy.AzureOAuth2
          ]
        ]

  ## Setting up Azure AD

  Login to Azure, and set up a new application:
  https://docs.microsoft.com/en-us/azure/active-directory/develop/v1-protocols-oauth-code#register-your-application-with-your-ad-tenant

  * `client_id` is the "Application ID".
  * `client_secret` has to be created with a new key for the application.
  * The callback URL (http://localhost:4000/auth/azure/callback) should be
    added to Reply URL's for the application
  * "Sign in and read user profile" permission has to be enabled.

  ### App ID URI for `resource`

  To find the App ID URI to be used for `resource`, in the Azure Portal, click
  Azure Active Directory, click Application registrations, open the
  application's Settings page, then click Properties.
  """
  use PowAssent.Strategy.OAuth2.Base

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(config) do
    tenant_id = Keyword.get(config, :tenant_id, "common")
    resource = Keyword.get(config, :resource, "https://graph.microsoft.com/")

    [
      site: "https://login.microsoftonline.com",
      authorize_url: "/#{tenant_id}/oauth2/authorize",
      token_url: "/#{tenant_id}/oauth2/token",
      authorization_params: [response_mode: "query", response_type: "code", resource: resource]
    ]
  end

  @spec normalize(Keyword.t(), map()) :: {:ok, map()}
  def normalize(_config, user) do
    {:ok, %{
      "uid"        => user["sub"],
      "name"       => "#{user["given_name"]} #{user["family_name"]}",
      "email"      => user["email"] || user["upn"],
      "first_name" => user["given_name"],
      "last_name"  => user["family_name"]}}
  end

  @spec get_user(Keyword.t(), map()) :: {:ok, map()}
  def get_user(config, token) do
    user =
      token["id_token"]
      |> String.split(".")
      |> Enum.at(1)
      |> Base.decode64!(padding: false)
      |> Helpers.decode_json!(config)

      {:ok, user}
  end
end
