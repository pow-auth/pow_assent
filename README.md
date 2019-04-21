# PowAssent

[![Build Status](https://travis-ci.org/danschultzer/pow_assent.svg?branch=master)](https://travis-ci.org/danschultzer/pow_assent) [![hex.pm](http://img.shields.io/hexpm/v/pow_assent.svg?style=flat)](https://hex.pm/packages/pow_assent)

Use Google, Github, Twitter, Facebook, or add your custom strategy for authorization to your Pow enabled Phoenix app.

## Features

* Collects required user id field from the user if the user id is missing from the provider
* Multiple providers can be used for accounts
  * When removing authentication, user is validated for password or alternative provider
* You can add your custom strategy with ease
* Includes the following base strategies:
  * [OAuth 1.0](lib/pow_assent/strategies/oauth.ex)
  * [OAuth 2.0](lib/pow_assent/strategies/oauth2.ex)
* Includes the following provider strategies:
  * [Azure AD](lib/pow_assent/strategies/azure_oauth2.ex)
  * [Basecamp](lib/pow_assent/strategies/basecamp.ex)
  * [Discord](lib/pow_assent/strategies/discord.ex)
  * [Facebook](lib/pow_assent/strategies/facebook.ex)
  * [Github](lib/pow_assent/strategies/github.ex)
  * [Google](lib/pow_assent/strategies/google.ex)
  * [Instagram](lib/pow_assent/strategies/instagram.ex)
  * [Slack](lib/pow_assent/strategies/slack.ex)
  * [Twitter](lib/pow_assent/strategies/twitter.ex)
  * [VK](lib/pow_assent/strategies/vk.ex)

## Installation

Add PowAssent to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # ...
    {:pow_assent, "~> 0.2.3"},

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

It's required to set up [Pow](https://github.com/danschultzer/pow#getting-started-phoenix) first. You can [run these quick setup](guides/POW.md) instructions if Pow hasn't already been set up.

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
pow_assent_authorization_path  GET     /auth/:provider/new          PowAssent.Phoenix.AuthorizationController :new
pow_assent_authorization_path  DELETE  /auth/:provider              PowAssent.Phoenix.AuthorizationController :delete
pow_assent_authorization_path  GET     /auth/:provider/callback     PowAssent.Phoenix.AuthorizationController :callback
pow_assent_registration_path   GET     /auth/:provider/add-user-id  PowAssent.Phoenix.RegistrationController  :add_user_id
pow_assent_registration_path   POST    /auth/:provider/create       PowAssent.Phoenix.RegistrationController  :create
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
<h1>Registration</h1>

<%= for link <- PowAssent.Phoenix.ViewHelpers.provider_links(@conn),
  do: content_tag(:span, link) %>
```

It'll automatically link with "Sign in with PROVIDER" or "Remove PROVIDER authentication" depending on if there's an authenticated user in the connection.

### Setting up a provider

PowAssent has [multiple strategies](lib/pow_assent/strategies) that you can use. Let's go through how to set up the Github strategy.

First, register [a new app on Github](https://github.com/settings/applications/new) and add `http://localhost:4000/auth/github/callback` as the callback URL. Then add the following to `config/config.exs` and add the client id and client secret:

```elixir
config :my_app, :pow_assent,
  providers: [
    github: [
      client_id: "REPLACE_WITH_CLIENT_ID",
      client_secret: "REPLACE_WITH_CLIENT_SECRET",
      strategy: PowAssent.Strategy.Github
    ]
  ]
```

Now start (or restart) your Phoenix app, and visit `http://localhost:4000/auth/github/new`.

## Custom provider

You can add your own custom strategy.

Here's an example of an OAuth 2.0 implementation using [`PowAssent.Strategy.OAuth2.Base`](lib/pow_assent/strategies/oauth2/base.ex):

```elixir
defmodule TestProvider do
  use PowAssent.Strategy.OAuth2.Base

  def default_config(_config) do
    [
      site: "http://localhost:4000/",
      authorize_url: "http://localhost:4000/oauth/authorize",
      token_url: "http://localhost:4000/oauth/access_token",
      user_url: "/user",
      authorization_params: [scope: "email profile"]
    ]
  end

  def normalize(_config, user) do
    %{
      "uid"   => user["sub"],
      "name"  => user["name"],
      "email" => user["email"]
    }
  end
end
```

You can also use [`PowAssent.Strategy`](lib/pow_assent/strategy.ex):

```elixir
defmodule TestProvider do
  @behaviour PowAssent.Strategy

  @spec authorize_url(Keyword.t()) :: {:ok, %{url: binary()}} | {:error, term()}
  def authorize_url(config) do
    # Generate authorization url
  end

  @spec callback(Keyword.t(), map()) :: {:ok, %{user: map()}} | {:error, term()}
  def callback(config, params) do
    # Handle callback response
  end
end
```

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

Add `messages_backend: MyAppWeb.Pow.Messages` to your configuration. You can find all messages in [`PowAssent.Phoenix.Messages`](lib/pow_assent/phoenix/messages.ex).

## Populate fields

To populate fields in your user struct that are fetched from the provider, you only need to cast them in `user_identity_changeset/4` method like so:

```elixir
defmodule MyApp.Users.User do
  use PowAssent.Ecto.Schema
  # ...

  def user_identity_changeset(user_or_changeset, user_identity, attrs, user_id_attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:custom_field_1, :customer_field_2])
    |> pow_assent_user_identity_changeset(user_identity, attrs, user_id_attrs)
  end
end
```

The fields available can be found in the `normalize/2` method of [the strategy](lib/pow_assent/strategies/).

## Disable registration

You can disable registration by only using `pow_assent_authorization_routes/0` in `router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  # ...

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

If you would like HTTP/2 support, you should consider adding [`Mint`](https://github.com/ninenines/mint) to your project.

Update `mix.exs`:

```elixir
def deps do
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
  http_adapter: PowAssent.HTTPAdapter.Mint
```

## Pow Extensions

### PowEmailConfirmation

The e-mail fetched from the provider is assumed already confirmed, and the user will have `:email_confirmed_at` set when inserted. If a user enters an e-mail then the user will have to confirm their e-mail before they can sign in.

### PowInvitation

PowAssent works out of the box with PowInvitation. If a user identity is created, the an invited user will have the `:invitation_accepted_at` set.

Provider links will have an `invitation_token` query param if an invited user exists in the connection. This will be used in the authorization callback flow to load the invited user.

## Security concerns

All sessions created through PowAssent provider authentication are temporary. However, it's a good idea to do some housekeeping in your app and make sure that you have the level of security as warranted by the scope of your app. That may include requiring users to re-authenticate before viewing or editing their user details.

## LICENSE

(The MIT License)

Copyright (c) 2018-2019 Dan Schultzer & the Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
