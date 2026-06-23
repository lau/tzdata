defmodule Tzdata.HTTPClient.Hackney do
  @moduledoc false

  @behaviour Tzdata.HTTPClient

  if Code.ensure_loaded?(:hackney) do
    @impl true
    def get(url, headers, options) do
      with {:ok, status, headers, result} <- :hackney.get(url, headers, "", options),
           {:ok, body} <- get_body(result) do
        {:ok, {status, headers, body}}
      end
    end

    defp get_body(result) when is_binary(result) do
      # Hackney 4.x returns the body as a binary in the result from :hackney.get
      {:ok, result}
    end
    defp get_body(client_ref) do
      # Hackney 1.x returns a client_ref that we can fetch the body from
      :hackney.body(client_ref)
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

        {:hackney, "~> 4.0"}

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
