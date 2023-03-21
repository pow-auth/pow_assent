defmodule Mix.Tasks.PowAssent.Ecto.Gen.SchemaTest do
  use PowAssent.Test.Mix.TestCase

  alias Mix.Tasks.PowAssent.Ecto.Gen.Schema

  @expected_file Path.join(["lib", "pow_assent", "user_identities", "user_identity.ex"])

  test "generates schema file", context do
    File.cd!(context.tmp_path, fn ->
      Schema.run([])

      assert File.exists?(@expected_file)

      content = File.read!(@expected_file)

      assert content =~ "defmodule PowAssent.UserIdentities.UserIdentity do"
      assert content =~ "user: PowAssent.Users.User"
      assert content =~ "timestamps()"
    end)
  end

  test "generates with :binary_id", context do
    options = ~w(--binary-id)

    File.cd!(context.tmp_path, fn ->
      Schema.run(options)

      assert File.exists?(@expected_file)

      file = File.read!(@expected_file)

      assert file =~ "@primary_key {:id, :binary_id, autogenerate: true}"
      assert file =~ "@foreign_key_type :binary_id"
    end)
  end

  test "doesn't make duplicate files", context do
    File.cd!(context.tmp_path, fn ->
      Schema.run([])

      assert_raise Mix.Error, "schema file can't be created, there is already a schema file in lib/pow_assent/user_identities/user_identity.ex.", fn ->
        Schema.run([])
      end
    end)
  end
end
