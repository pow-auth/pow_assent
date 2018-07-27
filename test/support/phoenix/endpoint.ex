defmodule PowAssent.Test.Phoenix.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :pow_assent

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session,
    store: :cookie,
    key: "_binaryid_key",
    signing_salt: "secret"

  plug PowAssent.Test.Phoenix.Plug.Session

  plug PowAssent.Test.Phoenix.Router
end
