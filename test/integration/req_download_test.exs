defmodule Tzdata.Integration.ReqDownloadTest do
  use ExUnit.Case

  @moduletag :integration
  @moduletag timeout: 60_000

  alias Tzdata.HTTPClient.Req, as: ReqClient

  @iana_url "https://data.iana.org/time-zones/tzdata-latest.tar.gz"

  describe "Req adapter with real IANA data" do
    test "can perform HEAD request to get content-length" do
      assert {:ok, {status, headers}} = ReqClient.head(@iana_url, [], [])
      assert status == 200

      content_length =
        headers
        |> Enum.find(fn {k, _v} -> String.downcase(k) == "content-length" end)
        |> elem(1)
        |> String.to_integer()

      assert content_length > 100_000  # Reasonable size for tzdata archive
    end

    test "can perform HEAD request to get last-modified header" do
      assert {:ok, {status, headers}} = ReqClient.head(@iana_url, [], [])
      assert status == 200

      last_modified =
        Enum.find_value(headers, fn {k, v} ->
          if String.downcase(k) == "last-modified", do: v
        end)

      assert is_binary(last_modified)
      assert String.length(last_modified) > 0
    end

    test "can download actual IANA tzdata file" do
      assert {:ok, {status, _headers, body}} = ReqClient.get(@iana_url, [], [])
      assert status == 200
      assert is_binary(body)
      assert byte_size(body) > 100_000  # Reasonable size for tzdata archive

      # Verify it's a gzip file
      assert binary_part(body, 0, 2) == <<0x1F, 0x8B>>
    end

    test "handles follow_redirect option correctly" do
      # Test with a URL that redirects (if IANA uses redirects)
      assert {:ok, {status, _headers, body}} =
        ReqClient.get(@iana_url, [], [follow_redirect: true])

      assert status == 200
      assert is_binary(body)
      assert byte_size(body) > 100_000
    end

    test "sends custom headers in real request" do
      custom_headers = [{"User-Agent", "tzdata-test"}]

      assert {:ok, {status, _headers, body}} =
        ReqClient.get(@iana_url, custom_headers, [])

      assert status == 200
      assert is_binary(body)
    end
  end
end
