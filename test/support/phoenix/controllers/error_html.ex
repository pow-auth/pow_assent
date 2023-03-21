defmodule PowAssent.Test.Phoenix.ErrorHTML do
  @moduledoc false
  use PowAssent.Test.Phoenix.Web, :html

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
