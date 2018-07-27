defmodule PowAssent.Phoenix.RegistrationTemplate do
  @moduledoc false
  use Pow.Phoenix.Template

  template :add_user_id, :html,
  """
  <h2>Register</h2>

  <%= Pow.Phoenix.HTML.FormTemplate.render([
    {:text, {:changeset, :pow_user_id_field}}
  ]) %>
  """
end
