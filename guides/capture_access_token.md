# Capture access token

By default, access tokens are not recorded. If you wish to capture the access tokens to use for future you can add the field to your user identity table and update the user identity schema:

```elixir
# priv/repo/migrations/TIMESTAMP_add_access_token_to_user_identities.ex
defmodule PowAssent.Test.Ecto.Repo.Migrations.AddAccessTokenToUserIdentities do
  use Ecto.Migration

  def change do
    alter table(:user_identities) do
      add :access_token, :string
      add :refresh_token, :string
    end
  end
end
```

```elixir
# lib/my_app/user_identities/user_identity.ex
defmodule MyApp.UserIdentities.UserIdentity do
  use Ecto.Schema
  use PowAssent.Ecto.UserIdentities.Schema,
    user: MyApp.Users.User

  schema "user_identities" do
    field :access_token, :string
    field :refresh_token, :string

    pow_assent_identity_fields()

    timestamps()
  end

  def changeset(identity_or_changeset, attrs) do
    token_params = Map.get(attrs, "token", attrs)

    identity_or_changeset
    |> pow_assent_changeset(attrs)
    |> Ecto.Changeset.cast(token_params, [:access_token, :refresh_token])
    |> Ecto.Changeset.validate_required([:access_token])
  end
end
```

Now access tokens can be retrieved by loading the user identity:

```elixir
identity = MyApp.Repo.get_by(MyApp.UserIdentities.UserIdentity, provider: provider, user_id: user.id)
```