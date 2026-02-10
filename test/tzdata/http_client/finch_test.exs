defmodule Tzdata.HTTPClient.FinchTest do
  use ExUnit.Case, async: false

  alias Tzdata.HTTPClient.Finch, as: FinchClient

  @moduletag :finch

  setup_all do
    # Start Finch pool for tests if not already started
    case Process.whereis(Tzdata.Finch) do
      nil ->
        {:ok, _pid} = Finch.start_link(name: Tzdata.Finch)

      _pid ->
        :ok
    end

    on_exit(fn ->
      # Clean up Finch pool after all tests
      case Process.whereis(Tzdata.Finch) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end
    end)

    :ok
  end

  describe "get/3" do
    test "successfully performs GET request with HTTPS URL" do
      url = "https://httpbin.org/get"
      headers = []
      options = []

      assert {:ok, {status, response_headers, body}} = FinchClient.get(url, headers, options)
      assert status == 200
      assert is_list(response_headers)
      assert is_binary(body)
      assert body =~ "httpbin"
    end

    test "successfully performs GET request with follow_redirect option" do
      # httpbin.org/redirect/1 redirects to /get
      url = "https://httpbin.org/redirect/1"
      headers = []
      options = [follow_redirect: true]

      assert {:ok, {status, response_headers, body}} = FinchClient.get(url, headers, options)
      assert status == 200
      assert is_list(response_headers)
      assert is_binary(body)
    end

    test "successfully performs GET request with custom headers" do
      url = "https://httpbin.org/headers"
      headers = [{"X-Custom-Header", "test-value"}]
      options = []

      assert {:ok, {status, _response_headers, body}} = FinchClient.get(url, headers, options)
      assert status == 200
      assert body =~ "X-Custom-Header"
      assert body =~ "test-value"
    end

    test "returns error for invalid URL" do
      url = "https://this-domain-does-not-exist-12345.com"
      headers = []
      options = []

      assert {:error, _reason} = FinchClient.get(url, headers, options)
    end

    test "returns 3xx status when follow_redirect is false" do
      # httpbin.org/redirect/1 returns a 302 redirect
      url = "https://httpbin.org/redirect/1"
      headers = []
      options = [follow_redirect: false]

      assert {:ok, {status, response_headers, _body}} = FinchClient.get(url, headers, options)
      assert status in [301, 302, 307, 308]
      assert List.keyfind(response_headers, "location", 0) != nil
    end

    test "returns error for too many redirects" do
      # httpbin.org/redirect/15 redirects 15 times, exceeding default max of 10
      url = "https://httpbin.org/redirect/15"
      headers = []
      options = [follow_redirect: true]

      assert {:error, :too_many_redirects} = FinchClient.get(url, headers, options)
    end

    test "successfully follows redirects with custom max_redirects" do
      # httpbin.org/redirect/3 redirects 3 times
      url = "https://httpbin.org/redirect/3"
      headers = []
      options = [follow_redirect: true, max_redirects: 5]

      assert {:ok, {status, _response_headers, body}} = FinchClient.get(url, headers, options)
      assert status == 200
      assert is_binary(body)
    end

    test "returns error when max_redirects is too low" do
      # httpbin.org/redirect/5 redirects 5 times
      url = "https://httpbin.org/redirect/5"
      headers = []
      options = [follow_redirect: true, max_redirects: 3]

      assert {:error, :too_many_redirects} = FinchClient.get(url, headers, options)
    end
  end

  describe "head/3" do
    test "successfully performs HEAD request with HTTPS URL" do
      url = "https://httpbin.org/get"
      headers = []
      options = []

      assert {:ok, {status, response_headers}} = FinchClient.head(url, headers, options)
      assert status == 200
      assert is_list(response_headers)
    end

    test "successfully performs HEAD request with custom headers" do
      url = "https://httpbin.org/headers"
      headers = [{"X-Custom-Header", "test-value"}]
      options = []

      assert {:ok, {status, response_headers}} = FinchClient.head(url, headers, options)
      assert status == 200
      assert is_list(response_headers)
    end

    test "returns error for invalid URL" do
      url = "https://this-domain-does-not-exist-12345.com"
      headers = []
      options = []

      assert {:error, _reason} = FinchClient.head(url, headers, options)
    end
  end
end
