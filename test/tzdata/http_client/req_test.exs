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
  end
end
