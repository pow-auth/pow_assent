# PowAssent

[![Build Status](https://travis-ci.org/danschultzer/pow_assent.svg?branch=master)](https://travis-ci.org/danschultzer/pow_assent) [![hex.pm](http://img.shields.io/hexpm/v/pow_assent.svg?style=flat)](https://hex.pm/packages/pow_assent)

Use Google, Github, Twitter, Facebook, Basecamp, VK or add your own strategy for authorization to your Pow Phoenix app.

## Features

* Collects required user id field if missing user id from provider
* Multiple providers can be used for accounts
  * When removing auth: Validates user has password or another provider authentication
* Github, Google, Twitter, Facebook, Basecamp and VK strategies included
* You can add your custom strategy with ease

## Installation

Add PowAssent to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # ...
    {:pow_assent, "~> 0.1"}
    # ...
  ]
end
```

Run `mix deps.get` to install it.

## Getting started

Install the necessary files:

```bash
mix pow.install
```

This will add the following files to your app:

```bash
LIB_PATH/user_identities/user_identity.ex
PRIV_PATH/repo/migrations/TIMESTAMP_create_user_identities.ex
```

Update `LIB_PATH/users/user.ex`:

```elixir
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema
  use PowAssent.Ecto.Schema

  schema "users" do
    has_many :user_identities,
      MyApp.UserIdentities.UserIdentity,
      on_delete: :delete_all

    # ...
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

```text
pow_assent_authorization_path  GET     /auth/:provider/new                       PowAssent.Phoenix.AuthorizationController :new
pow_assent_authorization_path  DELETE  /auth/:provider                           PowAssent.Phoenix.AuthorizationController :delete
pow_assent_authorization_path  GET     /auth/:provider/callback                  PowAssent.Phoenix.AuthorizationController :callback
pow_assent_registration_path  GET     /auth/:provider/add-user-id               PowAssent.Phoenix.RegistrationController :add_user_id
pow_assent_registration_path  POST    /auth/:provider/create                    PowAssent.Phoenix.RegistrationController :create
```

Remember to run the new migrations: `mix ecto.setup`.

## Setting up a provider

Strategies for Twitter, Facebook, Google, Github and Basecamp are included. We'll go through how to set up the Github strategy.

First, register [a new app on Github](https://github.com/settings/applications/new) and add `http://localhost:4000/auth/github/callback` as callback URL. Then add the following to `config/config.exs` and add the client id and client secret:

```elixir
config :my_app_web, :pow_assent,
  providers:
       [
         github: [
           client_id: "REPLACE_WITH_CLIENT_ID",
           client_secret: "REPLACE_WITH_CLIENT_SECRET",
           strategy: PowAssent.Strategy.Github
        ]
      ]
```

Now start (or restart) your Phoenix app, and visit `http://localhost:4000/registrations/new`. You'll see a "Sign in with Github" link.

## Provider links

You can use `PowAssent.Phoeinx.ViewHelpers.provider_links/1` to add provider links to your `registration` and `session` template files:

```elixir
<h1>Registration</h1>

<%= for link <- PowAssent.Phoenix.ViewHelpers.provider_links(@conn),
  do: content_tag(:span, link) %>
```

It'll automatically check if a user has been authenticated, and if said user has a user identity for the provider, linking respectively to "Sign in with PROVIDER" and "Remove PROVIDER authentication".

## Custom provider

You can add your own strategy. Here's an example of an OAuth 2.0 implementation:

```elixir
defmodule TestProvider do
  use PowAssent.Strategy

  alias PowAssent.Strategy.OAuth2, as: OAuth2Helper
  alias OAuth2.Strategy.AuthCode

  def authorize_url(config, conn) do
    OAuth2Helper.authorize_url(conn, set_config(config))
  end

  def callback(config, conn, params) do
    config = set_config(config)

    config
    |> OAuth2Helper.callback(conn, params)
    |> normalize()
  end

  defp set_config(config) do
    [
      site: "http://localhost:4000/",
      authorize_url: "http://localhost:4000/oauth/authorize",
      token_url: "http://localhost:4000/oauth/access_token",
      user_url: "/user",
      authorization_params: [scope: "email profile"]
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, AuthCode)
  end

  defp normalize({:ok, %{conn: conn, user: user, client: client}}) do
    user = %{
      "uid"        => user["sub"],
      "name"       => user["name"],
      "email"      => user["email"]}

    {:ok, %{conn: conn, user: Helpers.prune(user), client: client}}
  end
  defp normalize({:error, error}), do: {:error, error}
end
```

## Security concerns

All sessions created through `PowAssent` provider authentication are temporary, and doesn't use have long term sessions. However, it's a good idea to do some housekeeping in your app and making sure that you have the level of security as warranted by the scope of your app. This may include requiring users to reauthenticate before viewing or editing their user details.

## LICENSE

(The MIT License)

Copyright (c) 2018 Dan Schultzer & the Contributors Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
