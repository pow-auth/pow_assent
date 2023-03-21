import Config

config :pow_assent, PowAssent.Test.Ecto.Repo,
  database: "pow_assent_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support/ecto/priv",
  url: System.get_env("POSTGRES_URL")

config :pow_assent, PowAssent.Test.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [
    formats: [html: PowAssent.Test.Phoenix.ErrorHTML],
    layout: false
  ]

config :pow_assent, PowAssent.Test.EmailConfirmation.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [
    formats: [html: PowAssent.Test.Phoenix.ErrorHTML],
    layout: false
  ]

config :pow_assent, PowAssent.Test.Invitation.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [
    formats: [html: PowAssent.Test.Phoenix.ErrorHTML],
    layout: false
  ]

config :pow_assent, PowAssent.Test.NoRegistration.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [
    formats: [html: PowAssent.Test.Phoenix.ErrorHTML],
    layout: false
  ]

config :pow_assent, PowAssent.Test.WithCustomChangeset.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [
    formats: [html: PowAssent.Test.Phoenix.ErrorHTML],
    layout: false
  ]

config :pow_assent, PowAssent.Test.Reauthorization.Phoenix.Endpoint,
  secret_key_base: String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2),
  render_errors: [
    formats: [html: PowAssent.Test.Phoenix.ErrorHTML],
    layout: false
  ]

config :phoenix, :json_library, Jason
