# Changelog

## v0.2.0 (2019-03-09)

### Changes

* Detached `Plug` from strategies
* Moved callback registration/session logic from plug to controllers
* Allow for disabling registration by setting just `pow_assent_authorize_routes/0` macro in router
* Ensure only `:pow_assent_params` session value only can be read with the same provider param used for the callback
* `token` now included in `PowAssent.Strategy.OAuth.callback/2` response
* Use `account_already_bound_to_other_user/1` message for already taken user identity in `PowAssent.Phoenix.RegistrationController`

### Update your custom strategies

Strategies no longer has access to a `Plug.Conn` struct. If you use a custom strategy, please update it so it reflects this setup:

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

## v0.1.0 (2019-02-28)

* Initial release
