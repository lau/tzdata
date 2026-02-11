defmodule Tzdata.HTTPClient.ReqTest do
  use ExUnit.Case, async: false

  alias Tzdata.HTTPClient.Req, as: ReqClient

  @moduletag :req

  describe "get/3" do
    test "successfully performs GET request" do
      url = "https://httpbin.org/get"
      headers = []
      options = []

      assert {:ok, {status, response_headers, body}} = ReqClient.get(url, headers, options)
      assert status == 200
      assert is_list(response_headers)
      assert is_binary(body)
      assert body =~ "httpbin"
    end

    test "follows redirects when follow_redirect is true" do
      url = "https://httpbin.org/redirect/1"
      headers = []
      options = [follow_redirect: true]

      assert {:ok, {status, response_headers, body}} = ReqClient.get(url, headers, options)
      assert status == 200
      assert is_list(response_headers)
      assert is_binary(body)
    end

    test "does not follow redirects when follow_redirect is false" do
      url = "https://httpbin.org/redirect/1"
      headers = []
      options = [follow_redirect: false]

      assert {:ok, {status, response_headers, _body}} = ReqClient.get(url, headers, options)
      assert status in [301, 302, 307, 308]
      # Should have location header
      assert Enum.any?(response_headers, fn {k, _v} -> String.downcase(k) == "location" end)
    end
  end

  describe "head/3" do
    test "successfully performs HEAD request" do
      url = "https://httpbin.org/get"
      headers = []
      options = []

      assert {:ok, {status, response_headers}} = ReqClient.head(url, headers, options)
      assert status == 200
      assert is_list(response_headers)
    end

    test "returns error for invalid URL" do
      url = "https://this-domain-does-not-exist-12345.com"
      headers = []
      options = []

      assert {:error, _reason} = ReqClient.head(url, headers, options)
    end
  end
end
