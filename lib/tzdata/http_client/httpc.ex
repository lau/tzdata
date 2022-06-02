defmodule Tzdata.HttpClient.Httpc do
  require Logger

  @behaviour Tzdata.HTTPClient

  @impl true
  def get(url, _headers, _options) when is_binary(url) do
    String.to_charlist(url) |> get([], [])
  end

  def get(url, _headers, _options) when is_list(url) do
    request = {url, []}

    {:ok, {{_, response, _}, headers, body}} = :httpc.request(:get, request, http_options(), [])

    {:ok, {response, headers, :erlang.list_to_binary(body)}}
  end

  @impl true
  def head(url, _headers, _options) when is_binary(url) do
    String.to_charlist(url) |> head([],[])
  end

  def head(url, _headers, _options) when is_list(url) do
    request = {url, []}

    {:ok, {{_, response, _}, headers, []}} = :httpc.request(:head, request, http_options(), [])

    {:ok, {response, headers}}
  end

  defp http_options() do
    [{:ssl, ssl_options()}]
  end

  defp ssl_options() do
    local_storage =  CAStore.file_path() |> String.to_charlist()

    [{:verify, :verify_peer},
     {:cacertfile, local_storage},
     {:depth, 2},
     #{:customize_hostname_check, [
     #  {:match_fun, :public_key.pkix_verify_hostname_match_fun(:https)}
     # ]}
    ]
  end

  ##
  # uses cacert file maintained elsewhere on the system
  ##
  defp custom_cacert(cacert) when is_binary(cacert) do
    cacert |> String.to_charlist()
  end

  defp custom_cacert(cacert) when is_list(cacert) do
    cacert
  end

end
