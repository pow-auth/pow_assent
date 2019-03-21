use Mix.Config

config :pow_assent, PowAssent.Test.Ecto.Repo,
  database: "pow_assent_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support/ecto/priv"

config :pow_assent, PowAssent.Test.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [view: PowAssent.Test.Phoenix.ErrorView, accepts: ~w(html json)]

config :pow_assent, PowAssent.Test.EmailConfirmation.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [view: PowAssent.Test.Phoenix.ErrorView, accepts: ~w(html json)]

config :pow_assent, PowAssent.Test.Invitation.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [view: PowAssent.Test.Phoenix.ErrorView, accepts: ~w(html json)]

config :pow_assent, PowAssent.Test.NoRegistration.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [view: PowAssent.Test.Phoenix.ErrorView, accepts: ~w(html json)]

config :phoenix, :json_library, Jason
