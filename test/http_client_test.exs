defmodule Tzdata.HTTPClientTest do
  use ExUnit.Case, async: true

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
    assert {:ok, {200, headers}} = Tzdata.HTTPClient.Hackney.head(@url, [], [])
    assert Enum.any?(headers, fn {k, _v} -> String.downcase(k) == "content-length" end)
  end
end
