defmodule Mix.Tasks.PowAssent.InstallTest do
  use PowAssent.Test.Mix.TestCase

  alias Mix.Tasks.PowAssent.Install

  @tmp_path Path.join(["tmp", inspect(Install)])

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "runs" do
    File.cd!(@tmp_path, fn ->
      Install.run([])
    end)
  end

  test "raises error in umbrella app" do
    File.cd!(@tmp_path, fn ->
      File.write!("mix.exs", """
      defmodule Umbrella.MixProject do
        use Mix.Project

        def project do
          [apps_path: "apps"]
        end
      end
      """)

      Mix.Project.in_project(:umbrella, ".", fn _ ->
        assert_raise Mix.Error, "mix pow_assent.install can't be used in umbrella apps. Run mix pow_assent.ecto.install in your ecto app directory.", fn ->
          Install.run([])
        end
      end)
    end)
  end
end
