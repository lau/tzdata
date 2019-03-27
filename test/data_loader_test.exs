defmodule DataLoaderTest do
  use ExUnit.Case, async: true
  alias Tzdata.DataLoader

  @source_data_dir "test/tzdata_fixtures/source_data/"

  describe "release_version_for_dir" do
    test "it reads the version file" do
      assert DataLoader.release_version_for_dir(@source_data_dir) == "2015f"
    end
  end
end
