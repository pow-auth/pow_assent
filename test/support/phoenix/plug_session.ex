defmodule PowAssent.Test.Phoenix.Plug.Session do
  @moduledoc false
  def init(_config), do: Pow.Plug.Session.init([
    user: PowAssent.Test.Ecto.Users.User,
    repo: PowAssent.Test.Phoenix.MockRepo,
    routes_backend: PowAssent.Test.Phoenix.Pow.Routes,
    otp_app: :pow_assent])

  def call(conn, config) do
    config = Keyword.merge(config, Application.get_env(:pow_assent_test, :config, []))

    Pow.Plug.Session.call(conn, config)
  end
end
