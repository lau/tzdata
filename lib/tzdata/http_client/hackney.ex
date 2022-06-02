defmodule Tzdata.HTTPClient.Hackney do
  @moduledoc false

  @behaviour Tzdata.HTTPClient

  if Code.ensure_loaded?(:hackney) do
    @impl true
    def get(url, headers, options) do
      with {:ok, status, headers, client_ref} <- :hackney.get(url, headers, "", options),
           {:ok, body} <- :hackney.body(client_ref) do
        {:ok, {status, headers, body}}
      end
    end

    @impl true
    def head(url, headers, options) do
      with {:ok, status, headers} <- :hackney.head(url, headers, "", options) do
        {:ok, {status, headers}}
      end
    end
  else
    @message """
    missing :hackney dependency

    Tzdata requires a HTTP client in order to automatically update timezone
    database.

    In order to use the built-in adapter based on Hackney HTTP client, add the
    following to your mix.exs dependencies list:

        {:hackney, "~> 1.0"}

    See README for more information.
    """

    @impl true
    def get(_url, _headers, _options) do
      raise @message
    end

    @impl true
    def head(_url, _headers, _options) do
      raise @message
    end
  end
end
