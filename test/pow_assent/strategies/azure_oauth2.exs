defmodule PowAssent.Strategy.AzureOAuth2 do
  use PowAssent.Test.Phoenix.ConnCase

  import OAuth2.TestHelpers
  alias PowAssent.Strategy.AzureOAuth2

  @access_token "access_token"

  setup %{conn: conn} do
    bypass = Bypass.open()
    config = [site: bypass_server(bypass)]

    {:ok, conn: conn, config: config, bypass: bypass}
  end

  test "authorize_url/2", %{conn: conn, config: config} do
    assert {:ok, %{conn: _conn, url: url}} = AzureOAuth2.authorize_url(config, conn)
    assert url =~ "/common/oauth2/authorize?client_id="

    config = Keyword.put(config, :tenant_id, "8eaef023-2b34-4da1-9baa-8bc8c9d6a490")
    assert {:ok, %{conn: _conn, url: url}} = AzureOAuth2.authorize_url(config, conn)
    assert url =~ "/8eaef023-2b34-4da1-9baa-8bc8c9d6a490/oauth2/authorize?client_id="
  end

  describe "callback/2" do
    setup %{conn: conn, config: config, bypass: bypass} do
      params = %{"code" => "test", "redirect_uri" => "test"}

      {:ok, conn: conn, config: config, params: params, bypass: bypass}
    end

    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/common/oauth2/token", fn conn ->
         id_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0.eyJhdWQiOiIyZDRkMTFhMi1mODE0LTQ2YTctODkwYS0yNzRhNzJhNzMwOWUiLCJpc3MiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC83ZmU4MTQ0Ny1kYTU3LTQzODUtYmVjYi02ZGU1N2YyMTQ3N2UvIiwiaWF0IjoxMzg4NDQwODYzLCJuYmYiOjEzODg0NDA4NjMsImV4cCI6MTM4ODQ0NDc2MywidmVyIjoiMS4wIiwidGlkIjoiN2ZlODE0NDctZGE1Ny00Mzg1LWJlY2ItNmRlNTdmMjE0NzdlIiwib2lkIjoiNjgzODlhZTItNjJmYS00YjE4LTkxZmUtNTNkZDEwOWQ3NGY1IiwidXBuIjoiZnJhbmttQGNvbnRvc28uY29tIiwidW5pcXVlX25hbWUiOiJmcmFua21AY29udG9zby5jb20iLCJzdWIiOiJKV3ZZZENXUGhobHBTMVpzZjd5WVV4U2hVd3RVbTV5elBtd18talgzZkhZIiwiZmFtaWx5X25hbWUiOiJNaWxsZXIiLCJnaXZlbl9uYW1lIjoiRnJhbmsifQ."

         conn
         |> put_resp_content_type("application/json")
         |> send_resp(200, Jason.encode!(%{access_token: @access_token, id_token: id_token}))
      end)

      expected = %{
        "uid" => "JWvYdCWPhhlpS1Zsf7yYUxShUwtUm5yzPmw_-jX3fHY",
        "name" => "Frank Miller",
        "given_name" => "Frank",
        "family_name" => "Miller",
        "email" => "frank@contoso.com",
      }

      {:ok, %{user: user}} = AzureOAuth2.callback(config, conn, params)
      assert expected == user
    end
  end
end
