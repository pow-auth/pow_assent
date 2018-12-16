defmodule PowAssent.Strategy.BasecampTest do
  use PowAssent.Test.Phoenix.ConnCase

  import OAuth2.TestHelpers
  alias PowAssent.Strategy.Basecamp

  @access_token "access_token"

  setup %{conn: conn} do
    bypass = Bypass.open()
    config = [site: bypass_server(bypass)]

    {:ok, conn: conn, config: config, bypass: bypass}
  end

  test "authorize_url/2", %{conn: conn, config: config} do
    assert {:ok, %{conn: _conn, url: url}} = Basecamp.authorize_url(config, conn)
    assert url =~ "/authorization/new"
    assert url =~ "type=web_server"
  end

  describe "callback/2" do
    setup %{conn: conn, config: config, bypass: bypass} do
      params = %{"code" => "test", "redirect_uri" => "test"}

      {:ok, conn: conn, config: config, params: params, bypass: bypass}
    end

    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      accounts = [
        %{
          "product" => "bc3",
          "id" => 99_999_999,
          "name" => "Honcho Design",
          "href" => "https://3.basecampapi.com/99999999",
          "app_href" => "https://3.basecamp.com/99999999"
        },
        %{
          "product" => "bcx",
          "id" => 88_888_888,
          "name" => "Wayne Enterprises, Ltd.",
          "href" => "https://basecamp.com/88888888/api/v1",
          "app_href" => "https://basecamp.com/88888888"
        },
        %{
          "product" => "campfire",
          "id" => 44_444_444,
          "name" => "Acme Shipping Co.",
          "href" => "https://acme4444444.campfirenow.com",
          "app_href" => "https://acme4444444.campfirenow.com"
        }
      ]

      Bypass.expect_once(bypass, "POST", "/authorization/token", fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{access_token: @access_token}))
      end)

      Bypass.expect_once(bypass, "GET", "/authorization.json", fn conn ->
        assert_access_token_in_header(conn, @access_token)

        user = %{
          "expires_at" => "2012-03-22T16:56:48-05:00",
          "identity" => %{
            "id" => 9_999_999,
            "first_name" => "Jason",
            "last_name" => "Fried",
            "email_address" => "jason@basecamp.com"
          },
          "accounts" => accounts
        }

        conn
        |> put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(user))
      end)

      expected = %{
        "email" => "jason@basecamp.com",
        "name" => "Jason Fried",
        "first_name" => "Jason",
        "last_name" => "Fried",
        "accounts" => accounts,
        "uid" => "9999999"
      }

      {:ok, %{user: user}} = Basecamp.callback(config, conn, params)
      assert expected == user
    end
  end
end
