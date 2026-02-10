defmodule Tzdata.Integration.RealDownloadTest do
  use ExUnit.Case

  @moduletag :integration
  @moduletag timeout: 60_000

  alias Tzdata.DataLoader

  describe "real IANA timezone data operations" do
    test "can check last modified date of latest IANA release" do
      assert {:ok, datetime} = DataLoader.last_modified_of_latest_available()
      assert is_binary(datetime)
    end

    test "can check file size of latest IANA release" do
      # Note: This might fall back to GET if HEAD doesn't work as expected
      assert {:ok, size} = DataLoader.latest_file_size()
      assert is_integer(size)
      assert size > 100_000  # Reasonable size for tzdata archive
    end
  end

  describe "HTTP client behavior compatibility" do
    test "DataLoader.http_client/0 returns Finch client" do
      # Access the configuration to verify Finch is set as default
      http_client = Application.get_env(:tzdata, :http_client)
      assert http_client == Tzdata.HTTPClient.Finch
    end
  end
end
