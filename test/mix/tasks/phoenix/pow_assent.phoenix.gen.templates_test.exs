defmodule Mix.Tasks.PowAssent.Phoenix.Gen.TemplatesTest do
  use PowAssent.Test.Mix.TestCase

  alias Mix.Tasks.PowAssent.Phoenix.Gen.Templates

  @expected_template_files %{
    "registration_html" => ["add_user_id.html.heex"]
  }

  test "generates templates", context do
    File.cd!(context.tmp_path, fn ->
      Templates.run([])

      templates_path = Path.join(["lib", "pow_assent_web", "controllers", "pow_assent"])
      expected_dirs  = Map.keys(@expected_template_files)
      expected_files = Enum.map(expected_dirs, &"#{&1}.ex")

      assert expected_dirs -- ls(templates_path) == []
      assert expected_files -- ls(templates_path) == []

      for {dir, expected_files} <- @expected_template_files do
        files = templates_path |> Path.join(dir) |> ls()

        assert expected_files -- files == []
      end

      for base_name <- expected_dirs do
        content     = templates_path |> Path.join(base_name <> ".ex") |> File.read!()
        module_name = base_name |> Macro.camelize() |> String.replace_suffix("Html", "HTML")

        assert content =~ "defmodule PowAssentWeb.PowAssent.#{module_name} do"
        assert content =~ "use PowAssentWeb, :html"
        assert content =~ "embed_templates \"#{base_name}/*\""
      end
    end)
  end

  defp ls(path), do: path |> File.ls!() |> Enum.sort()
end
