defmodule PowAssent.Strategy.GithubTest do
  use PowAssent.Test.Phoenix.ConnCase

  import PowAssent.OAuthHelpers
  alias PowAssent.Strategy.Github

  @user_response %{
    login: "octocat",
    id: 1,
    avatar_url: "https://github.com/images/error/octocat_happy.gif",
    gravatar_id: "",
    url: "https://api.github.com/users/octocat",
    html_url: "https://github.com/octocat",
    followers_url: "https://api.github.com/users/octocat/followers",
    following_url: "https://api.github.com/users/octocat/following{/other_user}",
    gists_url: "https://api.github.com/users/octocat/gists{/gist_id}",
    starred_url: "https://api.github.com/users/octocat/starred{/owner}{/repo}",
    subscriptions_url: "https://api.github.com/users/octocat/subscriptions",
    organizations_url: "https://api.github.com/users/octocat/orgs",
    repos_url: "https://api.github.com/users/octocat/repos",
    events_url: "https://api.github.com/users/octocat/events{/privacy}",
    received_events_url: "https://api.github.com/users/octocat/received_events",
    type: "User",
    site_admin: false,
    name: "monalisa octocat",
    company: "GitHub",
    blog: "https://github.com/blog",
    location: "San Francisco",
    email: "octocat@github.com",
    hireable: false,
    bio: "There once was...",
    public_repos: 2,
    public_gists: 1,
    followers: 20,
    following: 0,
    created_at: "2008-01-14T04:33:35Z",
    updated_at: "2008-01-14T04:33:35Z"
  }

  @emails_response [
    %{
      email: "octocat@github.com",
      verified: true,
      primary: true,
      visibility: "public"
    }
  ]

  setup :setup_bypass

  setup context do
    config = Keyword.put(context[:config], :token_url, "/login/oauth/access_token")

    {:ok, Map.to_list(%{context | config: config})}
  end

  test "authorize_url/2", %{conn: conn, config: config} do
    assert {:ok, %{conn: _conn, url: url}} = Github.authorize_url(config, conn)
    assert url =~ "https://github.com/login/oauth/authorize?client_id="
  end

  describe "callback/2" do
    setup %{conn: conn, config: config, bypass: bypass} do
      params = %{"code" => "test", "redirect_uri" => "test"}

      {:ok, conn: conn, config: config, params: params, bypass: bypass}
    end

    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      expect_oauth2_access_token_request(bypass, uri: "/login/oauth/access_token")
      expect_oauth2_user_request(bypass, @user_response, uri: "/user")
      expect_oauth2_api_request(bypass, "/user/emails", @emails_response)

      expected = %{
        "email" => "octocat@github.com",
        "image" => "https://github.com/images/error/octocat_happy.gif",
        "name" => "monalisa octocat",
        "nickname" => "octocat",
        "uid" => "1",
        "urls" => %{"Blog" => "https://github.com/blog", "GitHub" => "https://github.com/octocat"}
      }

      {:ok, %{user: user}} = Github.callback(config, conn, params)
      assert expected == user
    end
  end
end
