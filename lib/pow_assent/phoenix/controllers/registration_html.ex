defmodule PowAssent.Phoenix.RegistrationHTML do
  @moduledoc false
  use Pow.Phoenix.Template

  # Credo will complain about unless statement but we want this first
  # credo:disable-for-next-line
  unless Pow.dependency_vsn_match?(:phoenix, "< 1.7.0") do
  template :add_user_id, :html,
  """
  <div class="mx-auto max-w-sm">
    <.header class="text-center">
      Register
    </.header>

    <.simple_form :let={f} for={<%= "@changeset" %>} as={:user} action={<%= "@action" %>} phx-update="ignore">
      <.error :if={<%= "@changeset.action" %>}>Oops, something went wrong! Please check the errors below.</.error>
      <.input field={<%= "f[\#{__user_id_field__("@changeset", :key)}]" %>} type={<%= __user_id_field__("@changeset", :type) %>} label={<%= __user_id_field__("@changeset", :label) %>} required />

      <:actions>
        <.button phx-disable-with="Registering..." class="w-full">
          Register <span aria-hidden="true">→</span>
        </.button>
      </:actions>
    </.simple_form>
  </div>
  """
  else
  # TODO: Remove when Phoenix 1.7 required
  template :add_user_id, :html,
  """
  <h2>Register</h2>

  <%= render_form([
    {:text, {:changeset, :pow_user_id_field}}
  ]) %>
  """
  end
end
