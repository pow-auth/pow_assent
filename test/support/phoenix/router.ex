defmodule PowAssent.Test.Phoenix.Router do
  @moduledoc false
  use Phoenix.Router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  # For testing email confirmation delivery
  use Pow.Extension.Phoenix.Router,
    extensions: [PowEmailConfirmation]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

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

    pow_extension_routes()
  end
end
