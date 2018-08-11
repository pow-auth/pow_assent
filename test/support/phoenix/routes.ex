defmodule PowAssent.Test.Phoenix.Routes do
  @moduledoc false
  use Pow.Phoenix.Routes

  def after_sign_in_path(_conn), do: "/session_created"

  def after_registration_path(_conn), do: "/registration_created"

  def after_sign_out_path(_conn), do: "/logged-out"
end
