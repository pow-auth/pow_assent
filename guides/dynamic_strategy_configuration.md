# Dynamic strategy configuration

In some cases it'll be necessary to dynamically update the provider strategy based on context. PowAssent includes `PowAssent.Plug.merge_provider_config/3` to dynamically update the provider configuration.

With this function the configuration can be updated based on attributes within the `conn`. A common use cases would be to update request parameters based on query parameters, such as setting the `connection` for Auth0 strategy:

```elixir
# lib/my_app_web/pow_assent_auth0_plug.ex
defmodule MyAppWeb.PowAssentAuth0Plug do
  def init(opts), do: opts

  def call(conn, _opts) do
    updated_config = [authorization_params: [connection: conn.params["connection"]]]

    PowAssent.Plug.merge_provider_config(conn, :auth0, updated_config)
  end
end

# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  # ...

  pipeline :configure_auth0 do
    plug MyAppWeb.PowAssentAuth0Plug
  end

  scope "/" do
    pipe_through [:browser, :configure_auth0]

    pow_routes()
    pow_assent_routes()
  end

  # ...
end
```

## Incremental authorization with Google

Google (and many other OAuth 2.0 providers that support granular `scope` configuration) strongly recommends to only request authorization with the minimum required scopes on first signup to keep the onboarding experience smooth. This will minimize the number of consent modals for the end-user by not asking for a bunch of permissions that your app won't even need up-front.

The below example will show how you enable [Incremental Authorization with the Google strategy](https://developers.google.com/identity/protocols/oauth2/web-server#incrementalAuth).

In this case, you may only want to request the `email` and `profile` scopes when user signs up, but enable opt-in Google Drive scope. Let's set up a custom plug to add the required scopes based on query param.

First we remove the scope from the config:

```elixir
# config/config.exs
config :my_app, :pow_assent,
  providers: [
    google: [
      client_id: System.get_env("GOOGLE_CLIENT_ID"),
      client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
      authorization_params: [
        access_type: "offline",
        prompt: "consent",
        include_granted_scopes: true
      ],
      strategy: Assent.Strategy.Google
    ]
  ]
```

Then we set up a plug to add optional scopes:

```elixir
# lib/my_app_web/pow_assent_google_incremental_auth_plug.ex
defmodule MyAppWeb.PowAssentGoogleIncrementalAuthPlug do
  @moduledoc """
  This plug enables incremental auth scopes for the Google strategy.

  ## Example

      plug MyAppWeb.PowAssentGoogleIncrementalAuthPlug
  """
  def init(opts), do: opts

  @required_scopes [
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/userinfo.profile"
  ]

  @optional_scopes %{
    "google_drive" => ["https://www.googleapis.com/auth/drive.file"]
  }

  def call(conn, _opts) do
    additional_scopes =
      @optional_scopes
      |> Map.keys()
      |> Enum.filter(& &1 in Map.keys(conn.params))
      |> Enum.map(& @optional_scopes[&1])

    scope = Enum.join(@required_scopes ++ additional_scopes, " ")

    PowAssent.Plug.merge_provider_config(conn, :google, authorization_params: [scope: scope])
  end
end
```

And finally we add this plug to the pipeline:

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  # ...

  pipeline :configure_google do
    plug MyAppWeb.PowAssentGoogleIncrementalAuthPlug
  end

  scope "/" do
    pipe_through [:browser, :configure_google]

    pow_routes()
    pow_assent_routes()
  end

  # ...
end
```

Now you can generate the authorization url with the `google_drive=true` query to enable `drive.file` permission:

```elixir
Routes.pow_assent_authorization_path(conn, :new, :google, google_drive: true)
```

You can add any number of additional optional scopes to the plug.

## Test modules

```elixir
# test/my_app_web/pow_assent_google_incremental_auth_plug_test.exs
defmodule MyAppWeb.PowAssentGoogleIncrementalAuthPlugTest do
  use MyAppWeb.ConnCase

  alias MyAppWeb.PowAssentGoogleIncrementalAuthPlug

  @pow_config [otp_app: :my_app]
  @provider :google
  @plug_opts []

  test "call/2 without additional scopes", %{conn: conn} do
    conn = run_plug(Routes.pow_assent_authorization_path(conn, :new, @provider))

    assert fetch_provider_scope(conn) ==
      "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"
  end

  test "call/2 with google_drive=true query", %{conn: conn} do
    conn = run_plug(Routes.pow_assent_authorization_path(conn, :new, @provider, google_drive: true))

    opts = PowAssentGoogleIncrementalAuthPlug.init(@plug_opts)
    conn = PowAssentGoogleIncrementalAuthPlug.call(conn, opts)

    assert fetch_provider_scope(conn) ==
      "https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/drive.file"
  end

  defp fetch_provider_scope(conn) do
    config = Pow.Plug.fetch_config(conn)

    config[:pow_assent][:providers][@provider][:authorization_params][:scope]
  end

  defp run_plug(uri) do
    opts = PowAssentGoogleIncrementalAuthPlug.init(@plug_opts)

    :get
    |> build_conn(uri)
    |> Pow.Plug.put_config(@pow_config)
    |> Plug.Conn.fetch_query_params()
    |> PowAssentGoogleIncrementalAuthPlug.call(opts)
  end
end
```