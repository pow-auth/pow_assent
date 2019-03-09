defmodule PowAssent.Phoenix.Router do
  @moduledoc """
  Handles Phoenix routing for PowAssent.

  ## Usage

  Configure `lib/my_project_web/router.ex` the following way:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        use Pow.Phoenix.Router
        use PowAssent.Phoenix.Router

        # ...

        scope "/" do
          pipe_through :browser

          pow_routes()
          pow_assent_routes()
        end

        # ...
      end
  """
  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__), only: [pow_assent_routes: 0, pow_assent_authorization_routes: 0, pow_assent_registration_routes: 0]
    end
  end

  @doc """
  PowAssent router macro.

  Use this macro to define the PowAssent routes.

  ## Example

      scope "/" do
        pow_assent_routes()
      end
  """
  defmacro pow_assent_routes do
    quote location: :keep do
      pow_assent_authorization_routes()
      pow_assent_registration_routes()
    end
  end

  @doc false
  defmacro pow_assent_authorization_routes do
    quote location: :keep do
      scope "/auth", PowAssent.Phoenix, as: "pow_assent" do
        resources "/:provider", AuthorizationController, singleton: true, only: [:new, :delete]
        get "/:provider/callback", AuthorizationController, :callback
      end
    end
  end

  @doc false
  defmacro pow_assent_registration_routes do
    quote location: :keep do
      scope "/auth", PowAssent.Phoenix, as: "pow_assent" do
        get "/:provider/add-user-id", RegistrationController, :add_user_id
        post "/:provider/create", RegistrationController, :create
      end
    end
  end
end
