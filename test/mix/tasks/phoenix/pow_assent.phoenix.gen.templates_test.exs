defmodule Mix.Tasks.PowAssent.Phoenix.Gen.TemplatesTest do
  use PowAssent.Test.Mix.TestCase

  alias Mix.Tasks.PowAssent.Phoenix.Gen.Templates

  @tmp_path Path.join(["tmp", inspect(Templates)])

  @expected_template_files %{
    "registration" => ["add_user_id.html.eex"]
  }
  @expected_views Map.keys(@expected_template_files)

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
    end)
  end

  defp ls(path), do: path |> File.ls!() |> Enum.sort()
end
