use Mix.Config

config :pow_assent, PowAssent.Test.Ecto.Repo,
  database: "pow_assent_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support/ecto/priv"

endpoint_opts = [
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [view: PowAssent.Test.Phoenix.ErrorView, accepts: ~w(html json)]]

config :pow_assent, PowAssent.Test.Phoenix.Endpoint, endpoint_opts
config :pow_assent, PowAssent.Test.Phoenix.MailerEndpoint, endpoint_opts

default_opts = [
  user: PowAssent.Test.Ecto.Users.User,
  repo: PowAssent.Test.Phoenix.MockRepo,
  routes_backend: PowAssent.Test.Phoenix.Routes,
  messages_backend: PowAssent.Test.Phoenix.Messages]

config :pow_assent, :pow, default_opts

config :pow_assent_mailer, :pow,
  Keyword.merge(default_opts,
    user: PowAssent.Test.Ecto.Users.EmailConfirmUser,
    mailer_backend: PowAssent.Test.Phoenix.MailerMock)
