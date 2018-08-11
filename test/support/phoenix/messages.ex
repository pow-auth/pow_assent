defmodule PowAssent.Test.Phoenix.Messages do
  @moduledoc false
  use Pow.Phoenix.Messages
  use Pow.Extension.Phoenix.Messages,
    extensions: [PowAssent,
      PowEmailConfirmation] # For testing email confirmation emails

  def pow_assent_signed_in(conn), do: "signed_in_#{conn.params["provider"]}"
  def pow_assent_user_has_been_created(conn), do: "user_created_#{conn.params["provider"]}"
end
