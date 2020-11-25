# ![PowAssent](assets/logo-full.svg)

![Build Status](https://img.shields.io/github/workflow/status/pow-auth/pow_assent/CI/master) [![hex.pm](http://img.shields.io/hexpm/v/pow_assent.svg?style=flat)](https://hex.pm/packages/pow_assent)

Use Google, Github, Twitter, Facebook, or add your custom strategy for authorization to your Pow enabled Phoenix app.

## Features

* Collects required user id field from the user if the user id is missing from the provider
* Multiple providers can be used for accounts
  * When removing authentication, user is validated for password or alternative provider
* You can add your custom strategy with ease
* Includes all strategies from [`Assent`](https://github.com/pow-auth/assent):
  * OAuth 1.0 - `Assent.Strategy.OAuth`
  * OAuth 2.0 - `Assent.Strategy.OAuth2`
  * OIDC - `Assent.Strategy.OIDC`
  * Apple Sign In - `Assent.Strategy.Apple`
  * Auth0 - `Assent.Strategy.Auth0`
  * Azure AD - `Assent.Strategy.AzureAD`
  * Basecamp - `Assent.Strategy.Basecamp`
  * Discord - `Assent.Strategy.Discord`
  * Facebook - `Assent.Strategy.Facebook`
  * Github - `Assent.Strategy.Github`
  * Gitlab - `Assent.Strategy.Gitlab`
  * Google - `Assent.Strategy.Google`
  * Instagram - `Assent.Strategy.Instagram`
  * Slack - `Assent.Strategy.Slack`
  * Twitter - `Assent.Strategy.Twitter`
  * VK - `Assent.Strategy.VK`
  * LINE Login - `Assent.Strategy.LINE`

## Installation

Add PowAssent to your list of dependencies in `mix.exs`:

```elixir
defp deps do
  [
    # ...
    {:pow_assent, "~> 0.4.10"},

    # Optional, but recommended for SSL validation with :httpc adapter
    {:certifi, "~> 2.4"},
    {:ssl_verify_fun, "~> 1.1"},
    # ...
  ]
end
```

Run `mix deps.get` to install it.

## Getting started

### Set up Pow

It's required to set up [Pow](https://github.com/danschultzer/pow#getting-started-phoenix) first. You can [run these quick setup](guides/set_up_pow.md) instructions if Pow hasn't already been set up.

If your user schema uses binary id, then run the PowAssent mix task(s) with the `--binary-id` flag.

### Set up PowAssent

Install the necessary files:

```bash
mix pow_assent.install
```

This will add the following files to your app:

```bash
LIB_PATH/user_identities/user_identity.ex
PRIV_PATH/repo/migrations/TIMESTAMP_create_user_identities.ex
```

Update `LIB_PATH/users/user.ex`:

```elixir
defmodule MyApp.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema
  use PowAssent.Ecto.Schema

  schema "users" do
    pow_user_fields()

    # ...

    timestamps()
  end

  # ..
end
```

Set up `router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  # ...

  pipeline :skip_csrf_protection do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_secure_browser_headers
  end

  # ...

  scope "/" do
    pipe_through :skip_csrf_protection

    pow_assent_authorization_post_callback_routes()
  end

  scope "/" do
    pipe_through [:browser]
    pow_routes()
    pow_assent_routes()
  end

  # ...
end
```

The following routes will now be available in your app:

```elixir
pow_assent_post_authorization_path  POST    /auth/:provider/callback     PowAssent.Phoenix.AuthorizationController :callback
pow_assent_authorization_path       GET     /auth/:provider/new          PowAssent.Phoenix.AuthorizationController :new
pow_assent_authorization_path       DELETE  /auth/:provider              PowAssent.Phoenix.AuthorizationController :delete
pow_assent_authorization_path       GET     /auth/:provider/callback     PowAssent.Phoenix.AuthorizationController :callback
pow_assent_registration_path        GET     /auth/:provider/add-user-id  PowAssent.Phoenix.RegistrationController  :add_user_id
pow_assent_registration_path        POST    /auth/:provider/create       PowAssent.Phoenix.RegistrationController  :create
```

Remember to run the new migrations with:

```bash
mix ecto.setup
```

### Modified Pow templates

If you're modifying the Pow templates, then you have to generate the PowAssent template too:

```elixir
mix pow_assent.phoenix.gen.templates
```

Otherwise, Pow will raise an error about missing template when the user id field template is shown.

### Provider links

You can use `PowAssent.Phoenix.ViewHelpers.provider_links/1` to add provider links to your template files:

```elixir
<%= for link <- PowAssent.Phoenix.ViewHelpers.provider_links(@conn),
  do: content_tag(:span, link) %>
```

This can be used in the `WEB_PATH/templates/pow/session/new.html.eex`, `WEB_PATH/templates/pow/registration/new.html.eex` and `WEB_PATH/templates/pow/registration/edit.html.eex` templates.

By default "Sign in with PROVIDER" link is shown. A "Remove PROVIDER authentication" link will be shown instead if the user is signed in and the user already have authorized with the provider.

You can also call `PowAssent.Phoenix.ViewHelpers.authorization_link/2` and `PowAssent.Phoenix.ViewHelpers.deauthorization_link/2` to generate a link for a single provider.

### Setting up a provider

[Assent](https://github.com/pow-auth/assent) provides many strategies that you can use. Let's go through how to set up the Github strategy.

First, register [a new app on Github](https://github.com/settings/applications/new) and add `http://localhost:4000/auth/github/callback` as the callback URL. Then add the following to `config/config.exs` and add the client id and client secret (for production keys you would want to set this in `config/prod.secret.exs`):

```elixir
config :my_app, :pow_assent,
  providers: [
    github: [
      client_id: "REPLACE_WITH_CLIENT_ID",
      client_secret: "REPLACE_WITH_CLIENT_SECRET",
      strategy: Assent.Strategy.Github
    ]
  ]
```

Now start (or restart) your Phoenix app, and visit `http://localhost:4000/auth/github/new`.

#### Nonce

For OIDC requests a nonce may be required. PowAssent can automatically generate the nonce if you pass `nonce: true` in the PowAssent configuration:

```elixir
config :my_app, :pow_assent,
  providers: [
    example: [
      client_id: "REPLACE_WITH_CLIENT_ID",
      site: "https://server.example.com",
      authorization_params: [scope: "user:read user:write"],
      nonce: true,
      strategy: Assent.Strategy.OIDC
    ]
  ]
```

## Custom provider

You can add your own custom strategy. See ["Custom Provider" section of Assent readme](https://github.com/pow-auth/assent#custom-provider) for more.

## I18n

The template can be generated and modified to use your Gettext module with `mix pow_assent.phoenix.gen.templates`

For flash messages, you should add them to your `Pow.Phoenix.Messages` module the same way as all Pow extension flash messages:

```elixir
defmodule MyAppWeb.Pow.Messages do
  use Pow.Phoenix.Messages
  use Pow.Extension.Phoenix.Messages,
    extensions: [PowAssent]

  import MyAppWeb.Gettext

  # ...

  def pow_assent_signed_in(conn) do
    provider = Phoenix.Naming.humanize(conn.params["provider"])

    gettext("You've been signed in with %{provider}.", provider)
  end
end
```

Add `messages_backend: MyAppWeb.Pow.Messages` to your Pow configuration. You can find all messages in `PowAssent.Phoenix.Messages`.

## Populate fields

To populate fields in your user struct that are fetched from the provider, you can override the `user_identity_changeset/4` method to cast them:

```elixir
defmodule MyApp.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema
  use PowAssent.Ecto.Schema

  schema "users" do
    field :custom_field, :string

    pow_user_fields()

    timestamps()
  end

  def user_identity_changeset(user_or_changeset, user_identity, attrs, user_id_attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:custom_field])
    |> pow_assent_user_identity_changeset(user_identity, attrs, user_id_attrs)
  end
end
```

The fields available can be found in the `normalize/2` method of the strategy module.

## Disable registration

You can disable registration by using `pow_assent_authorization_routes/0` instead of `pow_assent_routes/0` in `router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  # ...

  pipeline :skip_csrf_protection do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_secure_browser_headers
  end

  # ...

  scope "/" do
    pipe_through :skip_csrf_protection

    pow_assent_authorization_post_callback_routes()
  end

  scope "/" do
    pipe_through [:browser]
    pow_routes()
    pow_assent_authorization_routes()
  end

  # ...
end
```

PowAssent will pick it up in the authorization flow, and prevent creating a user if the registration path is missing.

## HTTP Adapter

By default Erlangs built-in `:httpc` is used for requests. SSL verification is automatically enabled when `:certifi` and `:ssl_verify_fun` packages are available. `:httpc` only supports HTTP/1.1.

If you would like HTTP/2 support, you should consider adding [`Mint`](https://github.com/elixir-mint/mint) to your project.

Update `mix.exs`:

```elixir
defp deps do
  [
    # ...
    {:mint, "~> 0.1.0"},
    {:castore, "~> 0.1.0"}, # Required for SSL validation
    # ...
  ]
end
```

Update the PowAssent configuration with:

```elixir
config :my_app, :pow_assent,
  http_adapter: Assent.HTTPAdapter.Mint
```

## Different module naming

PowAssent works by the assumption that you name your schema modules in the form of `[App].[Context].[Schema]`. If you have a different module naming, all you have to do is to add the `has_many` association to your user module like so:

```elixir
defmodule MyApp.Lib.User do
  use Ecto.Schema
  use Pow.Ecto.Schema
  use PowAssent.Ecto.Schema

  schema "users" do
    has_many :user_identities,
      MyApp.Lib.UserIdentity,
      on_delete: :delete_all,
      foreign_key: :user_id

    pow_user_fields()

    # ...

    timestamps()
  end

  # ..
end
```

Otherwise you'll get an error that reads:

```elixir
warning: invalid association `user_identities` in schema MyApp.Lib.User: associated schema MyApp.UserIdentities.UserIdentity does not exist
```

## Callback URL with HTTPS behind proxy

PowAssent uses the Phoenix URL generator to generate the callback URL used in OAuth and OIDC flows. If you run your Phoenix app behind a proxy, then you should ensure that HTTPS endpoints are generated:

```elixir
config :my_app, MyAppWeb.Endpoint,
  # ..,
  url: [scheme: "https", host: "example.com", port: 443]
```

## Pow Extensions

### PowEmailConfirmation

The e-mail fetched from the provider params is assumed confirmed if an `email_verified` key with value `true` also exists in the params. In that case the user will have `:email_confirmed_at` set. If `email_verified` isn't `true` in the provider params, or the user provides the e-mail, then the user will have to confirm their e-mail before they can sign in.

To prevent user enumeration attacks whenever there is a unique constraint error for e-mail the user will see confirmation required error message. However if `email_verified` is `true` in the provider params they will be see the form with changeset error. The same happens if `pow_prevent_information_leak: false` is set in `conn.private`.

### PowInvitation

PowAssent works out of the box with PowInvitation.

Provider links will have an `invitation_token` query param if an invited user exists in the connection. This will be used in the authorization callback flow to load the invited user. If a user identity is created, the invited user will have the `:invitation_accepted_at` set.

### PowPersistentSession

PowAssent doesn't support `PowPersistentSession`, as it's recommended to let the provider handle persistent session. `PowAssent.Plug.Reauthorization` can be used for this purpose.

You can enable the reauthorization plug in your `WEB_PATH/router.ex` by adding it to a pipeline:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  # ...

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug PowAssent.Plug.Reauthorization,
      handler: PowAssent.Phoenix.ReauthorizationPlugHandler
  end

  # ...
end
```

You can also enable `PowPersistentSession` by using the `PowAssent.Plug.put_create_session_callback/2` method:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  # ...

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :pow_assent_persistent_session
  end

  defp pow_assent_persistent_session(conn, _opts) do
    PowAssent.Plug.put_create_session_callback(conn, fn conn, _provider, _config ->
      PowPersistentSession.Plug.create(conn, Pow.Plug.current_user(conn))
    end)
  end

  # ...
```

## Security concerns

All sessions created through PowAssent provider authentication are temporary. However, it's a good idea to do some housekeeping in your app and make sure that you have the level of security as warranted by the scope of your app. That may include requiring users to re-authenticate before viewing or editing their user details.

## LICENSE

(The MIT License)

Copyright (c) 2018-2019 Dan Schultzer & the Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
