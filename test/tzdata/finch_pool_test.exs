defmodule Tzdata.FinchPoolTest do
  use ExUnit.Case

  test "Finch pool is started and available" do
    # Verify the Finch pool is registered
    assert Process.whereis(Tzdata.Finch) != nil

    # Verify it responds to a simple request
    url = "https://httpbin.org/get"
    request = Finch.build(:get, url)
    assert {:ok, %Finch.Response{}} = Finch.request(request, Tzdata.Finch)
  end
end
