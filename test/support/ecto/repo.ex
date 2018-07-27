defmodule PowAssent.Test.Ecto.Repo do
  @moduledoc false
  use Ecto.Repo, otp_app: :pow_assent

  def log(_cmd), do: nil
end
