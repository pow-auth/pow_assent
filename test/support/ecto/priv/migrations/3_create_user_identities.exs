require Pow.Ecto.Schema.Migration

PowAssent.Test.Ecto
|> PowAssent.Ecto.Identities.Schema.Migration.new("user_identities")
|> PowAssent.Ecto.Identities.Schema.Migration.gen()
|> Code.eval_string()
