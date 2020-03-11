# How to use PowAssent in an API

Follow the [Pow API guide](https://hexdocs.pm/pow/api.html) first to set up the API authorization plug.

## Routes

Add the authorization routes to `lib/my_app_web/router.ex`:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  # ...

  scope "/api/v1", MyAppWeb.API.V1, as: :api_v1 do
    pipe_through :api

     # ...
    get "/auth/:provider/new", AuthorizationController, :new
    post "/auth/:provider/callback", AuthorizationController, :callback
  end

  # ...
end
```

## Add API controllers

Create `lib/my_app_web/controllers/api/v1/authorization_controller.ex`:

```elixir
defmodule MyAppWeb.API.V1.AuthorizationController do
  use MyAppWeb, :controller

  alias Plug.Conn
  alias PowAssent.Plug

  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, %{"provider" => provider}) do
    conn
    |> Plug.authorize_url(provider, redirect_uri(conn))
    |> case do
      {:ok, url, conn} ->
        json(conn, %{data: %{url: url, session_params: conn.private[:pow_assent_session_params]}})

      {:error, _error, conn} ->
        conn
        |> put_status(500)
        |> json(%{error: %{status: 500, message: "An unexpected error occurred"}})
    end
  end

  defp redirect_uri(conn) do
    "https://client.example.com/auth/#{conn.params["provider"]}/callback"
  end

  @spec callback(Conn.t(), map()) :: Conn.t()
  def callback(conn, %{"provider" => provider} = params) do
    session_params = Map.fetch!(params, "session_params")
    params         = Map.drop(params, ["provider", "session_params"])

    conn
    |> Conn.put_private(:pow_assent_session_params, session_params)
    |> Plug.callback_upsert(provider, params, redirect_uri(conn, provider))
    |> case do
      {:ok, conn} ->
        json(conn, %{data: %{token: conn.private[:api_auth_token], renew_token: conn.private[:api_renew_token]}})

      {:error, conn} ->
        conn
        |> put_status(500)
        |> json(%{error: %{status: 500, message: "An unexpected error occurred"}})
    end
  end
end
```

`session_params` should be stored in the client. `https://client.example.com/auth/:provider/callback` is the  client side URI where the user will be redirected back to after authorization. The client should then send a POST request from the client to the callback URI in the API with the both the params received from the provider, and the `session_params` stored in the client.

That's it!

You can now set up your client to connect to your API and generate session tokens after successful provider callback. You can run the following curl commands to test it out:

```bash
$ curl -d http://localhost:4000/api/v1/auth/PROVIDER/new
{"data":{"url":"https://client.example.com/auth/PROVIDER/callback","session_params":{"state":"STATE"}}}

$ curl -X POST -d "code=CODE&session_params[state]=STATE" http://localhost:4000/api/v1/auth/PROVIDER/callback
{"data":{"renew_token":"RENEW_TOKEN","token":"AUTH_TOKEN"}}
```

## Test modules

```elixir
# test/my_app_web/controllers/api/v1/authorization_controller_test.exs
defmodule MyAppWeb.API.V1.AuthorizationControllerTest do
  use MyAppWeb.ConnCase

  @otp_app :my_app

  defmodule TestProvider do
    @moduledoc false
    @behaviour Assent.Strategy

    @impl true
    def authorize_url(config) do
      case config[:error] do
        nil   -> {:ok, %{url: "https://provider.example.com/oauth/authorize", session_params: %{a: 1}}}
        error -> {:error, error}
      end
    end

    @impl true
    def callback(_config, %{"code" => "valid"}), do: {:ok, %{user: %{"sub" => 1, "email" => "test@example.com"}, token: %{"access_token" => "access_Token"}}}
    def callback(_config, _params), do: {:error, "Invalid params"}
  end

  setup do
    Application.put_env(@otp_app, :pow_assent,
      providers: [
        test_provider: [strategy: TestProvider],
        invalid_test_provider: [strategy: TestProvider, error: :invalid]
      ])

    :ok
  end

  describe "new/2" do
    test "with valid config", %{conn: conn} do
      conn = get conn, Routes.api_v1_authorization_path(conn, :new, :test_provider)

      assert json = json_response(conn, 200)
      assert json["data"]["url"] == "https://provider.example.com/oauth/authorize"
      assert json["data"]["session_params"] == %{"a" => 1}
    end

    test "with error", %{conn: conn} do
      conn = get conn, Routes.api_v1_authorization_path(conn, :new, :invalid_test_provider)

      assert json = json_response(conn, 500)
      assert json["error"]["message"] == "An unexpected error occurred"
      assert json["error"]["status"] == 500
    end
  end

  describe "callback/2" do
    @valid_params   %{"code" => "valid", "session_params" => %{"a" => 1}}
    @invalid_params %{"code" => "invalid", "session_params" => %{"a" => 2}}

    test "with valid params", %{conn: conn} do
      conn = post conn, Routes.api_v1_authorization_path(conn, :callback, :test_provider, @valid_params)

      assert json = json_response(conn, 200)
      assert json["data"]["token"]
      assert json["data"]["renew_token"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post conn, Routes.api_v1_authorization_path(conn, :callback, :test_provider, @invalid_params)

      assert json = json_response(conn, 500)
      assert json["error"]["message"] == "An unexpected error occurred"
      assert json["error"]["status"] == 500
    end
  end
end
```
