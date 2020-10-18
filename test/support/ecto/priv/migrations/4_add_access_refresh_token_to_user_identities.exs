defmodule PowAssent.Test.Ecto.Repo.Migrations.AddAccessRefreshTokenToUserIdentities do
  use Ecto.Migration

  def change do
    alter table(:user_identities) do
      add :access_token, :string
      add :refresh_token, :string
    end
  end
end
