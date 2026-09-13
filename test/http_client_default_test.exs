defmodule Tzdata.HTTPClientDefaultTest do
  use ExUnit.Case, async: false

  test "default/0 picks the Httpc client when it can verify certificates" do
    if Tzdata.HTTPClient.Httpc.safe_to_use?() do
      assert Tzdata.HTTPClient.default() == Tzdata.HTTPClient.Httpc
    else
      expected =
        if Code.ensure_loaded?(:hackney),
          do: Tzdata.HTTPClient.Hackney,
          else: Tzdata.HTTPClient.Httpc

      assert Tzdata.HTTPClient.default() == expected
    end
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

    assert Application.get_env(:tzdata, :http_client) == :some_custom_client
  end
end
