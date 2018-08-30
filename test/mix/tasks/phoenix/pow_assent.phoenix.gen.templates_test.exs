defmodule Mix.Tasks.PowAssent.Phoenix.Gen.TemplatesTest do
  use PowAssent.Test.Mix.TestCase

  alias Mix.Tasks.PowAssent.Phoenix.Gen.Templates

  @tmp_path Path.join(["tmp", inspect(Templates)])

  @expected_template_files %{
    "registration" => ["add_user_id.html.eex"]
  }
  @expected_views @expected_template_files |> Map.keys()

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates templates" do
    File.cd!(@tmp_path, fn ->
      Templates.run([])

      templates_path = Path.join(["lib", "pow_assent_web", "templates", "pow_assent"])
      expected_dirs  = Map.keys(@expected_template_files)

      assert ls(templates_path) == expected_dirs

      for {dir, expected_files} <- @expected_template_files do
        files = templates_path |> Path.join(dir) |> ls()
        assert files == expected_files
      end

      views_path          = Path.join(["lib", "pow_assent_web", "views", "pow_assent"])
      expected_view_files = Enum.map(@expected_views, &"#{&1}_view.ex")
      view_content        = views_path |> Path.join("registration_view.ex") |> File.read!()

      assert ls(views_path) == expected_view_files
      assert view_content =~ "defmodule PowAssentWeb.PowAssent.RegistrationView do"
      assert view_content =~ "use PowAssentWeb, :view"

      for _ <- 1..2, do: assert_received({:mix_shell, :info, [_msg]})
      assert_received {:mix_shell, :info, [msg]}
      assert msg =~ "defmodule PowAssentWeb.Endpoint"
      assert msg =~ "otp_app: :pow"
      assert msg =~ "repo: PowAssent.Repo"
      assert msg =~ "user: PowAssent.Users.User"
      assert msg =~ "web_module: PowAssentWeb"
    end)
  end

  test "generates with :context_app" do
    options = ~w(--context-app test)

    File.cd!(@tmp_path, fn ->
      Templates.run(options)

      templates_path = Path.join(["lib", "test_web", "templates", "pow_assent"])
      dirs           = templates_path |> File.ls!() |> Enum.sort()

      assert dirs == Map.keys(@expected_template_files)

      views_path   = Path.join(["lib", "test_web", "views", "pow_assent"])
      view_content = views_path |> Path.join("registration_view.ex") |> File.read!()

      assert view_content =~ "defmodule TestWeb.PowAssent.RegistrationView do"
      assert view_content =~ "use TestWeb, :view"

      for _ <- 1..2, do: assert_received({:mix_shell, :info, [_msg]})
      assert_received {:mix_shell, :info, [msg]}
      assert msg =~ "defmodule TestWeb.Endpoint"
      assert msg =~ "otp_app: :test"
      assert msg =~ "repo: Test.Repo"
      assert msg =~ "user: Test.Users.User"
      assert msg =~ "web_module: TestWeb"
    end)
  end

  defp ls(path), do: path |> File.ls!() |> Enum.sort()
end
