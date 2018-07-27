defmodule PowAssent do
  @moduledoc false

  defmodule CallbackError do
    defexception [:message, :error, :error_uri]
  end

  defmodule CallbackCSRFError do
    defexception message: "CSRF detected"
  end

  defmodule RequestError do
    defexception [:message, :error]
  end

  defmodule ConfigurationError do
    defexception [:message]
  end
end
