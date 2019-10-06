defmodule PowAssent.Test.TestProvider do
  @moduledoc false
  use Assent.Strategy.OAuth2.Base

  @impl true
  def default_config(_config) do
    [
      site: "http://localhost:4000/",
      authorize_url: "/oauth/authorize",
      token_url: "/oauth/token",
      user_url: "/api/user"
    ]
  end

  @impl true
  def normalize(_config, user), do: {:ok, user}

  @spec expect_oauth2_flow(Bypass.t(), Keyword.t()) :: :ok
  def expect_oauth2_flow(bypass, opts \\ []) do
    put_oauth2_env(bypass)

    token_params = Keyword.get(opts, :token, %{"access_token" => "access_token"})
    user_params  = Map.merge(%{sub: "new_user", name: "Dan Schultzer"}, Keyword.get(opts, :user, %{}))

    PowAssent.Test.OAuth2TestCase.expect_oauth2_access_token_request(bypass, params: token_params)
    PowAssent.Test.OAuth2TestCase.expect_oauth2_user_request(bypass, user_params)
  end

  @spec put_oauth2_env(Bypass.t(), keyword()) :: :ok
  def put_oauth2_env(bypass, config \\ []) do
    Application.put_env(:pow_assent, :pow_assent,
      providers: [
        test_provider: Keyword.merge([
          client_id: "client_id",
          client_secret: "abc123",
          site: "http://localhost:#{bypass.port}",
          strategy: __MODULE__
        ], config)
      ]
    )
  end
end
