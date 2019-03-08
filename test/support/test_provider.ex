defmodule PowAssent.Test.TestProvider do
  @moduledoc false
  @behaviour PowAssent.Strategy

  alias PowAssent.Strategy.{OAuth2, OAuth2.Base}

  @spec default_config(Keyword.t()) :: Keyword.t()
  def default_config(_config) do
    [
      site: "http://localhost:4000/",
      authorize_url: "/oauth/authorize",
      token_url: "/oauth/token",
      user_url: "/api/user"
    ]
  end

  @spec normalize(Keyword.t(), map()) :: {:ok, map()}
  def normalize(_config, user) do
    {:ok, %{
      "uid"   => user["uid"],
      "name"  => user["name"],
      "email" => user["email"]}}
  end

  def authorize_url(config) do
    case config[:fail_authorize_url] do
      true -> {:error, "fail"}
      _    -> Base.authorize_url(config, __MODULE__)
    end
  end

  def callback(config, params), do: Base.callback(config, params, __MODULE__)

  defdelegate get_user(config, token), to: OAuth2

  @spec expect_oauth2_flow(Bypass.t(), Keyword.t()) :: :ok
  def expect_oauth2_flow(bypass, opts \\ []) do
    put_oauth2_env(bypass)

    token_params = Keyword.get(opts, :token, %{"access_token" => "access_token"})
    user_params  = Map.merge(%{uid: "new_user", name: "Dan Schultzer"}, Keyword.get(opts, :user, %{}))

    PowAssent.Test.OAuth2TestCase.expect_oauth2_access_token_request(bypass, params: token_params)
    PowAssent.Test.OAuth2TestCase.expect_oauth2_user_request(bypass, user_params)
  end

  @spec put_oauth2_env(Bypass.t(), keyword()) :: :ok
  def put_oauth2_env(bypass, config \\ []) do
    Application.put_env(:pow_assent, :pow_assent,
      providers: [
        test_provider: [
          client_id: "client_id",
          client_secret: "abc123",
          site: "http://localhost:#{bypass.port}",
          strategy: __MODULE__
        ] ++ config
      ]
    )
  end
end
