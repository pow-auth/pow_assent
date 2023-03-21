defmodule Mix.Tasks.PowAssent.Ecto.Gen.MigrationTest do
  use PowAssent.Test.Mix.TestCase

  alias Mix.Tasks.PowAssent.Ecto.Gen.Migration

  @migrations_path "migrations"

  setup context do
    {:ok, options: ["-r", inspect(context.repo)]}
  end

  test "generates migration", context do
    File.cd!(context.tmp_path, fn ->
      Migration.run(context.options)

      assert_received {:mix_shell, :info, ["* creating ./migrations"]}
      assert_received {:mix_shell, :info, ["* creating ./migrations/" <> _]}

      assert [_, migration_file] = @migrations_path |> File.ls!() |> Enum.sort()
      assert String.match?(migration_file, ~r/^\d{14}_create_user_identities\.exs$/)

      file = @migrations_path |> Path.join(migration_file) |> File.read!()

      assert file =~ "defmodule #{inspect(context.repo)}.Migrations.CreateUserIdentities do"
      assert file =~ "create table(:user_identities)"
      assert file =~ "add :provider, :string, null: false"
      assert file =~ "add :uid, :string, null: false"
      assert file =~ "add :user_id, references(\"users\", on_delete: :nothing)"
      assert file =~ "timestamps()"
    end)
  end

  test "doesn't make duplicate migrations", context do
    File.cd!(context.tmp_path, fn ->
      Migration.run(context.options)

      assert_raise Mix.Error, "migration can't be created, there is already a migration file with name CreateUserIdentities.", fn ->
        Migration.run(context.options)
      end
    end)
  end

  @tag repo: Repo
  test "generates with binary_id", context do
    options = context.options ++ ~w(--binary-id)

    File.cd!(context.tmp_path, fn ->
      Migration.run(options)

      assert [_, migration_file] = @migrations_path |> File.ls!() |> Enum.sort()
      assert String.match?(migration_file, ~r/^\d{14}_create_user_identities\.exs$/)

      file = @migrations_path |> Path.join(migration_file) |> File.read!()

      assert file =~ "create table(:user_identities, primary_key: false)"
      assert file =~ "add :id, :binary_id, primary_key: true"
      assert file =~ "add :user_id, references(\"users\", on_delete: :nothing, type: :binary_id)"
    end)
  end
end
