defmodule PowAssent.Store.Session do
  @moduledoc """
  Default module for session storage.
  """
  use Pow.Store.Base,
    ttl: :timer.minutes(5),
    namespace: "pow_assent_sessions"
end
