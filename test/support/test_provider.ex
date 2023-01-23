defmodule PowAssent.Test.TestProvider do
  @moduledoc false
  use Assent.Strategy.OAuth2.Base

  alias PowAssent.Test.OAuth2TestCase

  @impl true
  def default_config(_config) do
    [
      site: "http://localhost:4000/",
      authorize_url: "/oauth/authorize",
      token_url: "/oauth/token",
      user_url: "/api/user",
      authorization_params: [
        scope: "user:read user:write"
      ]
    ]
  end

  @impl true
  def normalize(_config, user), do: {:ok, user}

  @spec set_oauth2_test_endpoints(Keyword.t()) :: :ok
  def set_oauth2_test_endpoints(opts \\ []) do
    put_oauth2_env()

    token_params = Keyword.get(opts, :token, %{"access_token" => "access_token"})
    user_params  = Map.merge(%{sub: "new_user", name: "John Doe", email: "test@example.com"}, Keyword.get(opts, :user, %{}))

    OAuth2TestCase.add_oauth2_access_token_endpoint([params: token_params], opts[:access_token_assert_fn])
    OAuth2TestCase.add_oauth2_user_endpoint(user_params)
  end

  @spec put_oauth2_env(keyword()) :: :ok
  def put_oauth2_env(config \\ []) do
    url = Keyword.get(config, :site) || TestServer.url()
    %{host: host} = URI.parse(url)

    httpc_opts = Keyword.get(config, :site) || [
      ssl: [
        verify: :verify_peer,
        depth: 99,
        cacerts: TestServer.x509_suite().cacerts,
        verify_fun: {&:ssl_verify_hostname.verify_fun/3, check_hostname: to_charlist(host)},
        customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
      ]
    ]

    Application.put_env(:pow_assent, :pow_assent,
      providers: [
        test_provider: Keyword.merge([
          client_id: "client_id",
          client_secret: "abc123",
          site: url,
          strategy: __MODULE__
        ], config)
      ],
      http_adapter: {Assent.HTTPAdapter.Httpc, httpc_opts}
    )
  end
end
