defmodule PowAssent.HTTPResponse do
  @moduledoc false

  @type header :: {binary(), binary()}
  @type t      :: %__MODULE__{
    status: integer(),
    headers: [header()],
    body: binary()
  }

  defstruct status: 200, headers: [], body: ""
end
