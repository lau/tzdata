defmodule Tzdata.HTTPClient.Req do
  @moduledoc false

  @behaviour Tzdata.HTTPClient

  @impl true
  def get(url, headers, options) do
    follow_redirect = Keyword.get(options, :follow_redirect, false)

    req_options = [
      headers: headers,
      redirect: follow_redirect,
      decode_body: false
    ]

    case Req.request([method: :get, url: url] ++ req_options) do
      {:ok, %Req.Response{status: status, headers: response_headers, body: body}} ->
        # Convert headers to list of tuples to match HTTPClient behavior
        headers_list = Enum.map(response_headers, fn {k, v} -> {k, List.first(v) || v} end)
        {:ok, {status, headers_list, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def head(url, headers, _options) do
    case Req.request(method: :head, url: url, headers: headers) do
      {:ok, %Req.Response{status: status, headers: response_headers}} ->
        headers_list = Enum.map(response_headers, fn {k, v} -> {k, List.first(v) || v} end)
        {:ok, {status, headers_list}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
