defmodule Tzdata.DataLoaderTest do
  use ExUnit.Case

  test "default HTTP client is Req" do
    # This test verifies the default configuration
    default_client = Application.get_env(:tzdata, :http_client, :not_set)
    assert default_client == Tzdata.HTTPClient.Req
  end
end
