defmodule Tzdata.HTTPClient.Hackney do
  @moduledoc """
  HTTP client adapter based on the Hackney library.

  Deprecated: Hackney support is deprecated and will be removed in a
  future release. Upgrade to Erlang/OTP 25 or later to use the built-in
  `Tzdata.HTTPClient.Httpc` client instead, which requires no extra
  dependencies. See the README's "HTTP client and security" section for
  details.
  """

  @behaviour Tzdata.HTTPClient

  if Code.ensure_loaded?(:hackney) do
    require Logger

    @impl true
    @deprecated "Hackney support is deprecated, upgrade to Erlang/OTP 25+ to use Tzdata.HTTPClient.Httpc instead"
    def get(url, headers, options) do
      ensure_started!()

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
    @deprecated "Hackney support is deprecated, upgrade to Erlang/OTP 25+ to use Tzdata.HTTPClient.Httpc instead"
    def head(url, headers, options) do
      ensure_started!()

      with {:ok, status, headers} <- :hackney.head(url, headers, "", options) do
        {:ok, {status, headers}}
      end
    end

    # Hackney is an optional dependency of Tzdata, so it is not automatically
    # included in Tzdata's own `:applications` list and won't be started
    # just because it's compiled and available. Start it lazily here instead
    # of requiring users to add `:hackney` to their own `extra_applications`.
    defp ensure_started! do
      Logger.warning("""
      Tzdata is using Hackney as its HTTP client. Hackney support is
      deprecated and will be removed in a future release.

      Upgrade to Erlang/OTP 25 or later to use the built-in :httpc client
      instead, which requires no extra dependencies. See the README's
      "HTTP client and security" section for details.
      """)

      case Application.ensure_all_started(:hackney) do
        {:ok, _apps} -> :ok
        {:error, reason} -> raise "failed to start :hackney application: #{inspect(reason)}"
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
