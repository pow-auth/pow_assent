require Pow.Ecto.Schema.Migration

PowAssent.Test.Ecto
|> PowAssent.Ecto.UserIdentities.Schema.Migration.gen()
|> Code.eval_string()
