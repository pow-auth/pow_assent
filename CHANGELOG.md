# Changelog

## v0.4.4 (TBA)

* [`PowAssent.Plug`] Now uses `String.to_existing_atom/1` in `PowAssent.Plug.providers_for_current_user/1`
* [`PowAssent.Plug`] Fixed security issue by removing `String.to_atom/1` for user provided binary in `PowAssent.Plug.authorize_url/3` and `PowAssent.Plug.callback/4`
* [`PowAssent.Config`] `PowAssent.Config.get_provider_config/2` now accepts binary provider

## v0.4.3 (2019-11-20)

* Removed `:phoenix_html` dependency requirement
* Added Pow minimum requirement `~> 1.0.15`
* Use `Pow.Extension.Base` macro for new extension setup

## v0.4.2 (2019-11-13)

* Added support for POST callback from provider:
  * Added `pow_assent_authorization_post_callback_routes/0` macro to `PowAssent.Phoenix.Router`
  * Added `:skip_csrf_protection` pipeline example and scope with `pow_assent_authorization_post_callback_routes/0` call to the docs
  * Use `Pow.Phoenix.Router` macros to dynamically filter duplicate routes

## v0.4.1 (2019-10-08)

* Use Assent `v0.1.2` and set `:redirect_uri` in config for OAuth 2.0 callback phase

## v0.4.0 (2019-10-06)

**This release consists of major breaking changes.**

You'll have to change the `:strategy` setting in your provider configurations. For the most part it would just consists of renaming `PowAssent.Strategy.STRATEGY` to `Assent.Strategy.STRATEGY`.

If you have custom built strategies, you should can use `Assent.Strategy.normalize_userinfo/2` to conform the userinfo response from the API. `sub` is now expected instead of `uid`.

### Changes

* Use [`:assent` package](https://github.com/pow-auth/assent) for strategies. The following modules has been removed in favor of `Assent` modules:

  * `PowAssent.CallbackError`
  * `PowAssent.CallbackCSRFError`
  * `PowAssent.RequestError`
  * `PowAssent.ConfigurationError`
  * `PowAssent.HTTPAdapter`
  * `PowAssent.HTTPAdapter.Httpc`
  * `PowAssent.HTTPAdapter.Mint`
  * `PowAssent.Strategy.Auth0`
  * `PowAssent.Strategy.AzureOAuth2`
  * `PowAssent.Strategy.Basecamp`
  * `PowAssent.Strategy.Discord`
  * `PowAssent.Strategy.Facebook`
  * `PowAssent.Strategy.Github`
  * `PowAssent.Strategy.Gitlab`
  * `PowAssent.Strategy.Google`
  * `PowAssent.Strategy.Instagram`
  * `PowAssent.Strategy.OAuth`
  * `PowAssent.Strategy.OAuth.Base`
  * `PowAssent.Strategy.OAuth2`
  * `PowAssent.Strategy.OAuth2.Base`
  * `PowAssent.Strategy.Slack`
  * `PowAssent.Strategy.Twitter`
  * `PowAssent.Strategy.VK`
  * `PowAssent.Strategy`

* Callback params now conforms to [OpenID Connect Core 1.0 Standard Claims spec](https://openid.net/specs/openid-connect-core-1_0.html#rfc.section.5.1). During the callback phase, the following param keys will be renamed:

  * `sub` to `uid`
  * `preferred_username` to `username`

* The e-mail is no longer considered confirmed unless the callback params has an `email_verified` key set to true

* `PowAssent.Plug.authorize_url/3` generates a random nonce if `nonce: true` is set in the provider configuration

* Support for OpenID Connect and Apple Sign In through Assent

## v0.3.2 (2019-08-25)

* All links in docs generated with `mix docs` and on [hexdocs.pm](http://hexdocs.pm/pow/) now works
* Generated docs now uses lower case file name except for `README` and `CHANGELOG`
* Added Auth0 strategy
* Added Gitlab strategy

## v0.3.1 (2019-06-05)

* Added Pow minimum requirement `~> 1.0.9`
* Added repo `:prefix` support
* User identities are now upserted on authorization so additional params can be updated on authorization request. Following methods has been deprecated:
  * `PowAssent.Ecto.UserIdentities.Context.create/3` in favor of `PowAssent.Ecto.UserIdentities.Context.upsert/3`
  * `MyApp.UserIdentities.create/2` in favor of `MyApp.UserIdentities.upsert/2`
  * `MyApp.UserIdentities.pow_assent_create/2` in favor of `MyApp.UserIdentities.upsert/2`
  * `PowAssent.Operations.create/3` in favor of `PowAssent.Operations.upsert/3`
  * `PowAssent.Plug.create_identity/2` in favor of `PowAssent.Plug.upsert_identity/2`
* Use `Pow.Plug.get_plug/1` instead of pulling `:mod` from the config
* Fixed so `uid` can be an integer value in `PowAssent.Ecto.UserIdentities.Context`. Strategies are no longer expected to convert the `uid` value to binary. The following methods will accepts integer `uid`:
  * `PowAssent.Ecto.UserIdentities.Context.get_user_by_provider_uid/3`
  * `PowAssent.Ecto.UserIdentities.Context.upsert/3`
  * `PowAssent.Ecto.UserIdentities.Context.create_user/4`
* Fixed bug where invited user was not signed in after succesful authorization
* Fixed bug where releases with Elixir 1.9.0 didn't have `:httpc` available

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
