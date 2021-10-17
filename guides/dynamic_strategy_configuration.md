# Dynamic Strategy Configuration

In most cases, having a single set of configuration options defined per provider strategy is sufficient.
For more advanced authorization flows, however, you may find the need to customize strategy configuration dynamically on a per-request basis.

Pow Assent includes a built-in Plug helper function specifically for these more advanced configuration scenarios: [`PowAssent.Plug.merge_provider_config`](https://hexdocs.pm/pow_assent/PowAssent.Plug.html#merge_provider_config/3).

You can use this as a building block to create your own custom Plugs that modify the strategy configuration for a given provider. Since we have all of the Plug machinery at our disposal, we can alter the configuration on the basis of anything available in the `%Plug.Conn{}` struct. You could customize the strategy configuration for an individual user, or based on query params, or a bit of state stored in the session.

Below we'll walk through a concrete scenario of one possible dynamic configuration strategy, in order to add [Incremental Authorization](https://developers.google.com/identity/protocols/oauth2/web-server#incrementalAuth) support for for the Google provider strategy in your application.

# Supporting Incremental Authorization

Google (and many other OAuth 2.0 providers that support granular `scope` configuration) strongly recommends authorizing with the minimum required scopes on first signup to make the initial onboarding experience to your application smooth, to minimize wading through multiple consent modals and asking the user for a bunch of permissions that you may not even need up-front.

In this case, you may set your initial Google provider config in Pow Assent to simply request the `email` and `profile` scopes in the `authorization_params` like so:

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
        include_granted_scopes: true,
        scope:
          Enum.join(
            [
              "https://www.googleapis.com/auth/userinfo.email",
              "https://www.googleapis.com/auth/userinfo.profile"
            ],
            " "
          )
      ],
      strategy: Assent.Strategy.Google
    ]
  ]
```

But say that once your users have gone through the initial sign-up process, you have opt-in support for a file-sync mechanism that integrates with Google Drive and requires the `https://www.googleapis.com/auth/drive.file` scope. You could include a custom auth link as part of your settings or feature onboarding flow that requests the user to re-authorize with google with the added scope, taking advantage of `merge_provider_config` via a custom Plug.

In this case, for brevity, we can add a custom [Function plug](https://hexdocs.pm/phoenix/plug.html#function-plugs) to our router's existing `:browser` pipeline, like so:

```elixir
# router.ex
pipeline :browser do
  # ... misc existing plug pipeline bits
  plug(:accepts, ["html"])
  plug(:fetch_session)
  plug(:protect_from_forgery)
  plug(:put_secure_browser_headers)
  # vvv our custom plug
  plug(:put_google_drive_auth_scopes)
end

scope "/" do
  pipe_through([:browser])

  # make sure your custom plug/pipeline covers your pow assent routes,
  # so that they pick up the custom strategy configuration 
  pow_routes()
  pow_assent_routes()
  pow_extension_routes()
end
```

For our simplified example, we assume you have some application code in your `Users` context that determines whether a given user
has opted in to your Google Drive integration feature, `Users.should_request_google_drive_auth_scope?(current_user)`. This could just as easily be replaced with something that checks for a query string parameter, or a bit of state in your session storage.

Here's our function plug example, `put_google_drive_auth_scopes`:

```elixir
# could be inlined in router.ex or extended into a Module plug if you
# also want to accept custom arguments, or do more elaborate pattern matching
# or conn transformations
def put_google_drive_auth_scopes(conn, _opts) do
  current_user = conn.assigns[:current_user]
  if is_nil(current_user) || !Users.should_request_google_drive_auth_scope?(current_user) do
    # just return the conn unmodified if not logged in or should not request google drive auth scope
    conn
  else
    # otherwise, use `merge_provider_config` to override the auth scope config for the google provider,
    # returning the resulting modified `conn` struct.
    PowAssent.Plug.merge_provider_config(conn, :google,
      authorization_params: [
        access_type: "offline",
        prompt: "consent",
        include_granted_scopes: true,
        scope:
          Enum.join(
            [
              "https://www.googleapis.com/auth/userinfo.email",
              "https://www.googleapis.com/auth/userinfo.profile",
              # adding google drive scope request here
              "https://www.googleapis.com/auth/drive.file"
            ],
            " "
          )
      ]
    )
  end
end
```

Now, assuming you've implemented `Users.should_request_google_drive_auth_scope?(current_user)` for your application, any `authorization_link` you generate for the `:google` provider should result in directing the user to incrementally authorize access to the Google Drive file scope.

You could employ a similar strategy for a number of different use-cases outside of Incremental Authorization. Basically, any time you find the need to customize the settings for an individual provider on a per-user, per-request, or other dynamic basis, you can take advantage of `merge_provider_config` and a small bit of custom logic to get the job done.