defmodule Tzdata.DataLoaderTest do
  use ExUnit.Case, async: false
  alias Tzdata.HTTPClient.Mock
  doctest Tzdata.DataLoader
  import Mox

  setup :verify_on_exit!

  @default_download_url "https://data.iana.org/time-zones/tzdata-latest.tar.gz"

  @config_download_url "https://data.iana.org/time-zones/tzdata2024a.tar.gz"

  @custom_download_url "https://data.iana.org/time-zones/tzdata2024b.tar.gz"

  setup do
    client = Application.get_env(:tzdata, :http_client)

    :ok = Application.put_env(:tzdata, :http_client, Tzdata.HTTPClient.Mock)

    on_exit(fn ->
      Application.put_env(:tzdata, :http_client, client)
      :ok
    end)
  end

  describe "download_new/0" do
    test "when download_url config not set, should download content from default url" do
      expect(Mock, :get, fn @default_download_url, _, [follow_redirect: true] ->
        {:ok,
         {200, [{"Last-Modified", "Wed, 21 Oct 2015 07:28:00 GMT"}],
          File.read!("test/tzdata_fixtures/tzdata2024a.tar.gz")}}
      end)

      assert {:ok, 451_270, "2024a", _new_dir_name, "Wed, 21 Oct 2015 07:28:00 GMT"} =
               Tzdata.DataLoader.download_new()
    end

    test "when download_url config set, should download content from given url" do
      download_url = Application.get_env(:tzdata, :download_url)
      :ok = Application.put_env(:tzdata, :download_url, @config_download_url)

      on_exit(fn ->
        Application.put_env(:tzdata, :download_url, download_url)
        :ok
      end)

      expect(Mock, :get, fn @config_download_url, _, [follow_redirect: true] ->
        {:ok,
         {200, [{"Last-Modified", "Wed, 21 Oct 2015 07:28:00 GMT"}],
          File.read!("test/tzdata_fixtures/tzdata2024a.tar.gz")}}
      end)

      assert {:ok, 451_270, "2024a", _new_dir_name, "Wed, 21 Oct 2015 07:28:00 GMT"} =
               Tzdata.DataLoader.download_new()
    end
  end

  describe "download_new/1" do
    test "should download content from given url" do
      expect(Mock, :get, fn @custom_download_url, _, _ ->
        {:ok,
         {200, [{"Last-Modified", "Wed, 21 Oct 2015 07:28:00 GMT"}],
          File.read!("test/tzdata_fixtures/tzdata2024a.tar.gz")}}
      end)

      assert {:ok, 451_270, "2024a", _new_dir_name, "Wed, 21 Oct 2015 07:28:00 GMT"} =
               Tzdata.DataLoader.download_new(@custom_download_url)
    end
  end
end
