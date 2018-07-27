defmodule PowAssent.Phoenix.Router do
  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__), only: [pow_assent_routes: 0]
    end
  end

  defmacro pow_assent_routes do
    quote location: :keep do
      scope "/", PowAssent.Phoenix, as: "pow_assent" do
        unquote(__MODULE__.routes())
      end
    end
  end

  @moduledoc false
  def routes(_config \\ []) do
    quote location: :keep do
      scope "/auth" do
        resources "/:provider", AuthorizationController, singleton: true, only: [:new, :delete]
        get "/:provider/callback", AuthorizationController, :callback

        get "/:provider/add-user-id", RegistrationController, :add_user_id
        post "/:provider/create", RegistrationController, :create
      end
    end
  end
end
