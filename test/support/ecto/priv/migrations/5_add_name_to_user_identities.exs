defmodule PowAssent.Test.Ecto.Repo.Migrations.AddNameToToUserIdentities do
  use Ecto.Migration

  def change do
    alter table(:user_identities) do
      add :name, :string
    end
  end
end
