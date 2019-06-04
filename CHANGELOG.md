# Changelog

## v0.3.1 (TBA)

* User identities are now upserted on authorization so additional params can be updated on authorization request. Following methods has been deprecated:
  * `PowAssent.Ecto.UserIdentities.Context.create/3` in favor of `PowAssent.Ecto.UserIdentities.Context.upsert/3`
  * `MyApp.UserIdentities.create/2` in favor of `MyApp.UserIdentities.upsert/2`
  * `MyApp.UserIdentities.pow_assent_create/2` in favor of `MyApp.UserIdentities.upsert/2`
  * `PowAssent.Operations.create/3` in favor of `PowAssent.Operations.upsert/3`
  * `PowAssent.Plug.create_identity/2` in favor of `PowAssent.Plug.upsert_identity/2`
* Fixed so `uid` can be an integer value in `PowAssent.Ecto.UserIdentities.Context`. Strategies are no longer expected to convert the `uid` value to binary. The following methods will accepts integer `uid`:
  * `PowAssent.Ecto.UserIdentities.Context.get_user_by_provider_uid/3`
  * `PowAssent.Ecto.UserIdentities.Context.upsert/3`
  * `PowAssent.Ecto.UserIdentities.Context.create_user/4`
* Fixed bug where invited user was not signed in after succesful authorization

## v0.3.0 (2019-05-19)

* Added `PowAssent.Phoenix.ViewHelpers.authorization_link/2` and  `PowAssent.Phoenix.ViewHelpers.deauthorization_link/2`
* Removed `PowAssent.Phoenix.ViewHelpers.provider_link/3`
* Rewritten plug methods and controller handling so they now pass through additional params such as access token. This makes it possible to e.g. capture access tokens. Now there is a clear distinction between user identity params and user params, and most methods now accepts or returns two separate params. Following methods updated:
  * `MyApp.UserIdentities.create/3` changed to `MyApp.UserIdentities.create/2`
  * `MyApp.UserIdentities.pow_assent_create/3` changed to `MyApp.UserIdentities.pow_assent_create/2`
  * `PowAssent.Ecto.UserIdentities.Context.create/4` changed to `PowAssent.Ecto.UserIdentities.Context.create/3`
  * `MyApp.UserIdentities.create_user/4` changed to `MyApp.UserIdentities.create_user/3`
  * `MyApp.UserIdentities.pow_assent_create_user/4` changed to `MyApp.UserIdentities.pow_assent_create_user/3`
  * `PowAssent.Ecto.UserIdentities.Context.create_user/5` changed to `PowAssent.Ecto.UserIdentities.Context.create_user/4`
  * `PowAssent.Operations.create/4` changed to `PowAssent.Operations.create/3`
  * `PowAssent.Operations.create_user/5` changed to `PowAssent.Operations.create_user/4`
  * `PowAssent.Plug.callback/4` now returns a tuple with `{:ok, user_identity_params, user_params, conn}`
  * `PowAssent.Plug.authenticate/3` changed to `PowAssent.Plug.authenticate/2`
  * `PowAssent.Plug.create_identity/3` changed to `PowAssent.Plug.create_identity/2`
  * `PowAssent.Plug.create_user/4` now accepts `user_identity_params` instead of `provider` as second argument
  * `PowAssent.Plug.create_user/4` now expects `user_identity_params` rather than `provider` as second argument

## v0.2.4 (2019-04-25)

* Fixed so OAuth 2.0 access token request params are in the POST body in accordance with RFC 6749

## v0.2.3 (2019-04-09)

* Added `:authorization_params` config option to `PowAssent.Strategy.OAuth`
* Plug and Phoenix controller now handles `:session_params` rather than `:state` for any params that needs to be stored temporarily during authorization
* Added handling of `oauth_token_secret` to OAuth strategies
* Support any `:plug` version below `2.0.0`
* Fixed bug in `mix pow_assent.ecto.gen.migration` task where `--binary-id` flag didn't generate correct migration
* Support `:pow` version `1.0.5`

## v0.2.2 (2019-03-25)

* Fixed issue where user couldn't be created when PowEmailConfirmation was enabled

## v0.2.1 (2019-03-16)

* Improve mix task instructions

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
