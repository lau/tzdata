defmodule Tzdata.HTTPClient.Req do
  @moduledoc false

  @behaviour Tzdata.HTTPClient

  @impl true
  def get(url, headers, _options) do
    # Disable automatic response body decoding to return raw binary
    case Req.request(method: :get, url: url, headers: headers, decode_body: false) do
      {:ok, %Req.Response{status: status, headers: response_headers, body: body}} ->
        # Convert headers to list of tuples to match HTTPClient behavior
        headers_list = Enum.map(response_headers, fn {k, v} -> {k, List.first(v) || v} end)
        {:ok, {status, headers_list, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def head(_url, _headers, _options) do
    # Stub for now - will implement in Task 4
    {:error, :not_implemented}
  end
end
