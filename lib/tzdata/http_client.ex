defmodule Tzdata.HttpClient do
  @moduledoc """
  The purpose of the module is to provide a high level abstraction for http requests
  required to keep the the IANA tz database up to date.

  Currently implemented with httpc
  """

  require Logger

  @doc """
  get implements the http get method and takes a url as either a binary or charlist
  """

  @spec get(binary() | charlist()) :: {:ok, integer(), list(), binary()}
  def get(url) when is_binary(url) do
    String.to_charlist(url) |> get()
  end

  def get(url) when is_list(url) do
    request = {url, []}

    {:ok, {{_, response, _}, headers, body}} = :httpc.request(:get, request, http_options(), [])

    {:ok, response, headers, :erlang.list_to_binary(body)}
  end

  @doc """
  head implements the http head method and takes a url as either a binary or charlist
  """

  @spec head(binary() | charlist()) :: {:ok, integer(), list()}
  def head(url) when is_binary(url) do
    String.to_charlist(url) |> head()
  end

  def head(url) when is_list(url) do
    request = {url, []}

    {:ok, {{_, response, _}, headers, []}} = :httpc.request(:head, request, http_options(), [])

    {:ok, response, headers}
  end

  ##
  # sane defaults for http requests
  ##
  defp http_options() do
    [{:ssl, ssl_options()}]
  end

  ##
  # sane defaults for ssl options
  ##
  defp ssl_options() do
    cacert =
      case Application.fetch_env(:tzdata, :cacert) do
        {:ok, nil} -> packaged_cacert()
        {:ok, system_cacert} -> custom_cacert(system_cacert)
        _ -> packaged_cacert()
      end

    [{:verify, :verify_peer}, {:cacertfile, cacert}]
  end

  ##
  # uses packaged cacert file
  ##
  defp packaged_cacert() do
    local_storage = Tzdata.Util.data_dir() |> String.to_charlist()

    local_storage ++ '/cacert/cacert.pem'
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
