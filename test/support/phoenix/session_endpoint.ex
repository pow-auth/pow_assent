defmodule PowAssent.Test.Phoenix.SessionEndpoint do
  defmacro __using__(session_config) do
    quote do
      @moduledoc false
      use Phoenix.Endpoint, otp_app: :pow_assent_web

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

      plug Pow.Plug.Session, unquote(session_config)

      plug PowAssent.Test.Phoenix.Router
    end
  end
end
