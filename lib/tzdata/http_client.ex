
defmodule Tzdata.HttpClient do
  require Logger


  @spec get(binary() | char_list()) :: {:ok, any(), any(), any()}
  def get(url) when is_binary(url) do
    String.to_charlist(url) |> get()
  end

  def get(url) when is_list(url) do
   request = {url, []}

   {:ok, {{ _, response, _}, headers, body}} = :httpc.request(:get, request, [], [])

   {:ok, response, headers, :erlang.list_to_binary(body)}
  end


  @spec head(binary() | char_list()) :: {:ok, any(), any()}
  def head(url) when is_binary(url) do
    String.to_charlist(url) |> head()
  end

  def head(url) when is_list(url) do
   request = {url, []}

   {:ok, {{ _ ,response, _ }, headers,[] }} = :httpc.request(:head, request, [], [])

   {:ok, response, headers}

  end

end
