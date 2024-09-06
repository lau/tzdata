defmodule Tzdata.DataLoaderTest do
  use ExUnit.Case, async: false
  alias Tzdata.HTTPClient.Mock
  doctest Tzdata.DataLoader
  import Mox

  setup :verify_on_exit!

  setup do
    client = Application.get_env(:tzdata, :http_client)
    Application.put_env(:tzdata, :http_client, Tzdata.HTTPClient.Mock)

    Application.put_env(
      :tzdata,
      :download_url,
      "https://data.iana.org/time-zones/tzdata-latest.tar.gz"
    )

    on_exit(fn ->
      Application.put_env(:tzdata, :http_client, client)
      :ok
    end)
  end

  describe "download_new/1" do
    test "when url not given, should download content from default url" do
      expect(Mock, :get, fn "https://data.iana.org/time-zones/tzdata-latest.tar.gz",
                            _,
                            [follow_redirect: true] ->
        {:ok,
         {200, [{"Last-Modified", "Wed, 21 Oct 2015 07:28:00 GMT"}],
          File.read!("test/tzdata_fixtures/tzdata2024a.tar.gz")}}
      end)

      assert {:ok, 451_270, "2024a", _new_dir_name, "Wed, 21 Oct 2015 07:28:00 GMT"} =
               Tzdata.DataLoader.download_new()
    end

    test "when url given, should download content from given url" do
      expect(Mock, :get, fn "https://data.iana.org/time-zones/tzdata2024a.tar.gz", _, _ ->
        {:ok,
         {200, [{"Last-Modified", "Wed, 21 Oct 2015 07:28:00 GMT"}],
          File.read!("test/tzdata_fixtures/tzdata2024a.tar.gz")}}
      end)

      assert {:ok, 451_270, "2024a", _new_dir_name, "Wed, 21 Oct 2015 07:28:00 GMT"} =
               Tzdata.DataLoader.download_new(
                 "https://data.iana.org/time-zones/tzdata2024a.tar.gz"
               )
    end
  end
end
