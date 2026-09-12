defmodule Tzdata.HTTPClientTest do
  use ExUnit.Case, async: true

  @url "https://data.iana.org/time-zones/tzdata-latest.tar.gz"

  test "Httpc client can HEAD the IANA tzdata URL over verified HTTPS" do
    assert {:ok, {200, headers}} = Tzdata.HTTPClient.Httpc.head(@url, [], [])
    assert Enum.any?(headers, fn {k, _v} -> String.downcase(k) == "content-length" end)
  end

  test "Hackney client can HEAD the IANA tzdata URL over verified HTTPS" do
    assert {:ok, {200, headers}} = Tzdata.HTTPClient.Hackney.head(@url, [], [])
    assert Enum.any?(headers, fn {k, _v} -> String.downcase(k) == "content-length" end)
  end
end
