defmodule PowAssent.Strategy do
  @moduledoc """
  Used for creating strategies.

  ## Usage

  Set up `my_strategy.ex` the following way:

      defmodule MyStrategy do
        use PowAssent.Strategy

        def authorize_url(config, conn) do
          # generate authorization url
        end

        def callback(config, conn, params) do
          # return normalized user params map
        end
      end
  """
  alias Plug.Conn
  alias PowAssent.HTTPResponse

  @callback authorize_url(Keyword.t(), Conn.t()) ::
              {:ok, %{:conn => Conn.t(), :url => binary(), optional(atom()) => any()}}
              | {:error, %{conn: Conn.t(), error: any()}}
  @callback callback(Keyword.t(), Conn.t(), map()) ::
              {:ok, %{:conn => Conn.t(), :user => map(), optional(atom()) => any()}}
              | {:error, %{conn: Conn.t(), error: any()}}

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end

  @doc """
  Makes a HTTP request.
  """
  @spec request(atom(), binary(), binary() | nil, list(), Keyword.t()) :: {:ok, HTTPResponse.t()} | {:error, HTTPResponse.t()} | {:error, term()}
  def request(method, url, body, headers, config) do
    http_adapter = Keyword.get(config, :http_adapter, PowAssent.HTTPAdapter.Httpc)

    method
    |> http_adapter.request(url, body, headers)
    |> parse_status_response()
  end

  defp parse_status_response({:ok, %{status: status} = resp}) when status in 200..399 do
    {:ok, resp}
  end
  defp parse_status_response({:ok, %{status: status} = resp}) when status in 400..599 do
    {:error, resp}
  end
  defp parse_status_response({:error, reason}) do
    {:error, reason}
  end

  @doc """
  Decodes a request response.
  """
  @spec decode_response({atom(), any()}, Keyword.t()) :: {atom(), any()}
  def decode_response({status, %{body: body, headers: headers} = resp}, config) do
    case List.keyfind(headers, "content-type", 0) do
      {"content-type", "application/json" <> _rest} ->
        {status, %{resp | body: decode_json!(body, config)}}
      {"content-type", "application/x-www-form-urlencoded" <> _reset} ->
        {status, %{resp | body: URI.decode_query(body)}}
      _any ->
        {status, resp}
    end
  end
  def decode_response(any, _config), do: any

  @doc """
  Recursively prunes map for nil values.
  """
  @spec prune(map) :: map
  def prune(map) do
    map
    |> Enum.map(fn {k, v} -> if is_map(v), do: {k, prune(v)}, else: {k, v} end)
    |> Enum.filter(fn {_, v} -> not is_nil(v) end)
    |> Enum.into(%{})
  end

  @doc """
  Decode a JSON response to a map
  """
  @spec decode_json!(binary() | map(), Keyword.t()) :: map()
  def decode_json!(map, _config) when is_map(map), do: map
  def decode_json!(response, config) do
    json_library = Keyword.get(config, :json_library, default_json_library())
    json_library.decode!(response)
  end

  defp default_json_library do
    Application.get_env(:phoenix, :json_library, Poison)
  end

  @doc """
  Generates a URL
  """
  @spec to_url(binary(), binary(), Keyword.t()) :: binary()
  def to_url(site, uri, []), do: endpoint(site, uri)
  def to_url(site, uri, params) do
    endpoint(site, uri) <> "?" <> URI.encode_query(params)
  end

  defp endpoint(site, <<"/"::utf8, _::binary>> = uri),
    do: site <> uri
  defp endpoint(_site, url),
    do: url
end
