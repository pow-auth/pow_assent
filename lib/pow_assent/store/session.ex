defmodule PowAssent.Store.SessionCache do
  @moduledoc """
  Default module for session storage.
  """
  use Pow.Store.Base,
    ttl: :timer.minutes(15),
    namespace: "pow_assent_sessions"
end
