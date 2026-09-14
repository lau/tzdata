defmodule Tzdata.HTTPClientTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  @url "https://data.iana.org/time-zones/tzdata-latest.tar.gz"

  test "Httpc client can HEAD the IANA tzdata URL over verified HTTPS, when it can verify certificates" do
    case Tzdata.HTTPClient.Httpc.head(@url, [], []) do
      {:ok, {200, headers}} ->
        assert Tzdata.HTTPClient.Httpc.safe_to_use?()
        assert Enum.any?(headers, fn {k, _v} -> String.downcase(k) == "content-length" end)

      {:error, :unsupported_otp_release} ->
        # Erlang/OTP < 25: `:public_key.cacerts_get/0` isn't available, so
        # the client correctly refuses to download without verification.
        refute Tzdata.HTTPClient.Httpc.safe_to_use?()
    end
  end

  test "Hackney client can HEAD the IANA tzdata URL over verified HTTPS" do
    # Hackney support is deprecated: call it via `apply/3` so the compiler's
    # static `@deprecated` check doesn't fire, and capture the runtime
    # deprecation log it emits, since triggering both here is expected.
    # `capture_log/2` (rather than `with_log/1`, added in Elixir 1.13) keeps
    # this working on the oldest Elixir version this library supports.
    log =
      capture_log(fn ->
        send(self(), {:head_result, apply(Tzdata.HTTPClient.Hackney, :head, [@url, [], []])})
      end)

    assert_received {:head_result, result}
    assert {:ok, {200, headers}} = result
    assert Enum.any?(headers, fn {k, _v} -> String.downcase(k) == "content-length" end)
    assert log =~ "Hackney"
  end
end
