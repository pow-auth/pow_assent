# Migrating from legacy system

A common setup with Ueberauth is to have provider details as columns in the `users` table. To migrate from that you should copy over the provider details to the `user_identities` table.

The below shows an example with a legacy system using facebook:

```elixir
defmodule MyApp.Repo.Migrations.FacebookUserToUserIdentities do
  use Ecto.Migration

  import Ecto.Query
  alias MyApp.Repo

  def up do
    create_user_identities()

    alter table(:users) do
      remove :facebook_id
      remove :facebook_access_token
    end
  end

  def down do
    alter table(:users) do
      add :facebook_id, :string
      add :facebook_access_token, :string
    end

    flush()

    set_identity_columns()
  end

  defp create_user_identities() do
    user_identities =
      "users"
      |> where([u], not is_nil(u.facebook_id))
      |> select([u], %{user_id: u.id, provider: "facebook", uid: u.facebook_id, inserted_at: u.inserted_at, updated_at: u.inserted_at})
      # Or with access token:
      # |> select([u], %{user_id: u.id, provider: "facebook", uid: u.facebook_id, access_token: u.facebook_access_token, inserted_at: u.inserted_at, updated_at: u.inserted_at})
      |> Repo.all()

    Repo.insert_all("user_identities", user_identities)
  end

  defp set_identity_columns() do
    "user_identities"
    |> select([i], {i.user_id, %{facebook_id: i.uid}})
    # Or with access token:
    # |> select([i], {i.user_id, %{facebook_id: i.uid, facebook_access_token: i.access_token}})
    |> where([i], i.provider == "facebook")
    |> Repo.all()
    |> Enum.each(fn {id, update} ->
      "users"
      |> where([u], u.id == ^id)
      |> update(set: ^Map.to_list(update))
      |> Repo.update_all([])
    end)
  end
end
```
