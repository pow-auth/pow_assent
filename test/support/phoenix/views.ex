defmodule PowAssent.Test.Phoenix.LayoutView do
  @moduledoc false
  use Phoenix.View,
    root: "test/support/phoenix/templates",
    namespace: PowAssent.Test.Phoenix
end

defmodule PowAssent.Test.Phoenix.ErrorView do
  @moduledoc false
  def render("500.html", _assigns), do: "500.html"
  def render("400.html", _assigns), do: "400.html"
  def render("404.html", _assigns), do: "404.html"
end
