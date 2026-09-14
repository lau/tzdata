defmodule Tzdata.HTTPClient.Httpc do
  @moduledoc false

  require Logger

  @behaviour Tzdata.HTTPClient

  @impl true
  def get(url, headers, options) do
    request(:get, url, headers, options)
  end

  @impl true
  def head(url, headers, options) do
    with {:ok, {status, resp_headers, _body}} <- request(:head, url, headers, options) do
      {:ok, {status, resp_headers}}
    end
  end

  @doc false
  # Whether this client can verify TLS certificates on the running
  # Erlang/OTP: `:public_key.cacerts_get/0` must exist and actually return
  # a non-empty list of OS-trusted CA certificates.
  def safe_to_use? do
    match?([_ | _], safe_cacerts())
  end

  defp request(method, url, headers, options) do
    with {:ok, ssl_options} <- ssl_options() do
      http_options = [
        ssl: ssl_options,
        autoredirect: Keyword.get(options, :follow_redirect, false),
        timeout: :timer.seconds(30),
        connect_timeout: :timer.seconds(10)
      ]

      request = {String.to_charlist(url), to_charlist_headers(headers)}

      case :httpc.request(method, request, http_options, body_format: :binary) do
        {:ok, {{_http_version, status, _reason_phrase}, resp_headers, body}} ->
          {:ok, {status, from_charlist_headers(resp_headers), body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp ssl_options do
    case safe_cacerts() do
      [_ | _] = cacerts ->
        {:ok,
         [
           verify: :verify_peer,
           cacerts: cacerts,
           depth: 4,
           customize_hostname_check: [
             match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
           ],
           versions: [:"tlsv1.2", :"tlsv1.3"]
         ]}

      [] ->
        Logger.warning("""
        Tzdata cannot verify TLS certificates on this Erlang/OTP version.

        The built-in HTTP client verifies certificates using the OS-trusted
        CA bundle via `:public_key.cacerts_get/0`, which is only available
        (and populated) on Erlang/OTP 25 and later.

        To fix this, either:

          1. Upgrade to Erlang/OTP 25 or later, or
          2. Add a HTTP client dependency such as Hackney to your mix.exs and
             configure Tzdata to use it:

                 {:hackney, "~> 1.17 or ~> 4.0"}

             config :tzdata, :http_client, Tzdata.HTTPClient.Hackney

        See the README for more information.
        """)

        {:error, :unsupported_otp_release}
    end
  end

  # Returns the OS-trusted CA certificates, or `[]` if they are unavailable
  # (older OTP release, or OTP unable to locate/read the OS trust store).
  defp safe_cacerts do
    if Code.ensure_loaded?(:public_key) and function_exported?(:public_key, :cacerts_get, 0) do
      try do
        :public_key.cacerts_get()
      rescue
        _ -> []
      end
    else
      []
    end
  end

  defp to_charlist_headers(headers) do
    Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)
  end

  defp from_charlist_headers(headers) do
    Enum.map(headers, fn {k, v} -> {to_string(k), to_string(v)} end)
  end
end
