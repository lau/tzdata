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
    unsafe_reason() == nil
  end

  @doc false
  # Why this client cannot verify TLS certificates on the running
  # Erlang/OTP, or `nil` if it can:
  #
  #   * `:otp_too_old` - `:public_key.cacerts_get/0` does not exist
  #     (Erlang/OTP < 25).
  #   * `:no_cacerts` - it exists but returned no OS-trusted CA certificates.
  def unsafe_reason do
    cond do
      not cacerts_get_available?() -> :otp_too_old
      safe_cacerts() == [] -> :no_cacerts
      true -> nil
    end
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
        # `Tzdata.ReleaseUpdater` warns about this and skips automatic
        # updates, so this is only reached when calling the client directly.
        Logger.debug("Tzdata cannot verify TLS certificates on this Erlang/OTP version.")

        {:error, :unsupported_otp_release}
    end
  end

  # Returns the OS-trusted CA certificates, or `[]` if they are unavailable
  # (older OTP release, or OTP unable to locate/read the OS trust store).
  defp safe_cacerts do
    if cacerts_get_available?() do
      try do
        :public_key.cacerts_get()
      rescue
        _ -> []
      end
    else
      []
    end
  end

  defp cacerts_get_available? do
    Code.ensure_loaded?(:public_key) and function_exported?(:public_key, :cacerts_get, 0)
  end

  defp to_charlist_headers(headers) do
    Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)
  end

  defp from_charlist_headers(headers) do
    Enum.map(headers, fn {k, v} -> {to_string(k), to_string(v)} end)
  end
end
