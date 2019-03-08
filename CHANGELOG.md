# Changelog

## v0.2.0 (TBA)

### Changes

* Detached `Plug` from strategies

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
