defmodule Tzdata.HTTPClientDefaultTest do
  use ExUnit.Case, async: false

  test "default/0 is the built-in Httpc client" do
    assert Tzdata.HTTPClient.default() == Tzdata.HTTPClient.Httpc
  end

  test "an explicit :http_client config is what Tzdata.DataLoader ends up using" do
    previous = Application.get_env(:tzdata, :http_client)
    Application.put_env(:tzdata, :http_client, :some_custom_client)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:tzdata, :http_client)
        client -> Application.put_env(:tzdata, :http_client, client)
      end
    end)

    assert Tzdata.DataLoader.http_client() == :some_custom_client
  end
end
