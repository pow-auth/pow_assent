defmodule PowAssent.Test.Phoenix.ConnCase do
  @moduledoc false
  use ExUnit.CaseTemplate
  alias Phoenix.ConnTest
  alias PowAssent.Test.Phoenix.{Endpoint, Router}

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest, except: [get_flash: 2]
      import unquote(__MODULE__), only: [get_flash: 2]

      alias Router.Helpers, as: Routes

      @endpoint Endpoint
    end
  end

  setup do
    conn = ConnTest.build_conn()
    opts = Plug.Session.init(store: :cookie, key: "_binaryid_key", signing_salt: "secret")

    conn =
      conn
      |> Plug.Session.call(opts)
      |> Plug.Conn.fetch_session()

    {:ok, conn: conn}
  end

  # TODO: Remove when Phoenix 1.7 is required
  if Code.ensure_loaded?(Phoenix.Flash) do
    def get_flash(conn, key), do: Phoenix.Flash.get(conn.assigns.flash, key)
  else
    defdelegate get_flash(conn, key), to: Phoenix.Controller
  end
end
