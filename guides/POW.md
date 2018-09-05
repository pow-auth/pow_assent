# Set up Pow

First install the necessary files:

```mix
mix pow.install
```

Update `config/config.ex` with the following:

```elixir
config :my_app, :pow,
  user: MyApp.Users.User,
  repo: MyApp.Repo
```

Set up `WEB_PATH/endpoint.ex` to enable session based authentication:

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # ...

  plug Plug.Session,
    store: :cookie,
    key: "_my_app_key",
    signing_salt: "secret"

  plug Pow.Plug.Session, otp_app: :my_app

  # ...
end
```

Add Pow routes to `WEB_PATH/router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Pow.Phoenix.Router

  # ...

  pipeline :protected do
    plug Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
  end

  scope "/" do
    pipe_through :browser

    pow_routes()
  end

  # ...

  scope "/", MyAppWeb do
    pipe_through [:browser, :protected]

    # Protected routes ...
  end
end
```

Run `mix ecto.setup` and you can now visit `http://localhost:4000/registration/new` to create a new user.