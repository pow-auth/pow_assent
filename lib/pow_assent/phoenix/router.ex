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

        pipeline :skip_csrf_protection do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_flash
          plug :put_secure_browser_headers
        end

        scope "/" do
          pipe_through :skip_csrf_protection

          pow_assent_authorization_post_callback_routes()
        end

        scope "/" do
          pipe_through :browser

          pow_routes()
          pow_assent_routes()
        end

        # ...
      end

  The `:skip_csrf_protection` pipeline and
  `pow_assent_authorization_post_callback_routes/0` call is only necessary if
  you have strategies using POST callback such as `Assent.Strategy.Apple`. The default
  CSRF protection in Phoenix has to be skipped when using POST callback.
  """
  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__), only: [pow_assent_routes: 0, pow_assent_authorization_routes: 0, pow_assent_authorization_post_callback_routes: 0, pow_assent_registration_routes: 0, pow_assent_scope: 1]
    end
  end

  alias Pow.Phoenix.Router

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
      pow_assent_scope do
        Router.pow_resources "/:provider", AuthorizationController, singleton: true, only: [:new, :delete]
        Router.pow_route :get, "/:provider/callback", AuthorizationController, :callback
      end
    end
  end

  @doc false
  defmacro pow_assent_authorization_post_callback_routes do
    quote location: :keep do
      pow_assent_scope do
        scope "/", as: "post" do
          Router.pow_route :post, "/:provider/callback", AuthorizationController, :callback
        end
      end
    end
  end

  @doc false
  defmacro pow_assent_registration_routes do
    quote location: :keep do
      pow_assent_scope do
        Router.pow_route :get, "/:provider/add-user-id", RegistrationController, :add_user_id
        Router.pow_route :post, "/:provider/create", RegistrationController, :create
      end
    end
  end

  @doc false
  defmacro pow_assent_scope(do: context) do
    quote do
      scope "/auth", PowAssent.Phoenix, as: "pow_assent" do
        unquote(context)
      end
    end
  end
end
