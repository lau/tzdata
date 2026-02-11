defmodule Tzdata.ConfigTest do
  use ExUnit.Case

  test "default http_client is Req" do
    default_client = Application.get_env(:tzdata, :http_client)
    assert default_client == Tzdata.HTTPClient.Req
  end
end
