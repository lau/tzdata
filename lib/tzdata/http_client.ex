defmodule Tzdata.HttpClient do
  require Logger

  @spec get(binary() | charlist()) :: {:ok, integer(), any(), any()}
  def get(url) when is_binary(url) do
    String.to_charlist(url) |> get()
  end

  def get(url) when is_list(url) do
    request = {url, []}

    {:ok, {{_, response, _}, headers, body}} = :httpc.request(:get, request, http_options(), [])

    {:ok, response, headers, :erlang.list_to_binary(body)}
  end

  @spec head(binary() | charlist()) :: {:ok, integer(), any()}
  def head(url) when is_binary(url) do
    String.to_charlist(url) |> head()
  end

  def head(url) when is_list(url) do
    request = {url, []}

    {:ok, {{_, response, _}, headers, []}} = :httpc.request(:head, request, http_options(), [])

    {:ok, response, headers}
  end

  defp http_options() do
    [{:ssl, ssl_options()}]
  end

  defp ssl_options() do
    local_storage = Tzdata.Util.data_dir() |> String.to_charlist()

    [{:verify, :verify_peer}, {:cacertfile, local_storage ++ '/cacert/cacert.pem'}]
  end
end
