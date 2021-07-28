defmodule Tzdata.EtsHolderTest do
  use ExUnit.Case, async: false

  describe "load_ets_table/1" do
    test "Should load correctly with spaces and special characters in path" do
      {:ok, old_val} = Application.fetch_env(:tzdata, :data_dir)
      on_exit(fn -> Application.put_env(:tzdata, :data_dir, old_val) end)

      release_base_path = Path.join(System.tmp_dir!(), "release_path á")
      assert :ok = Application.put_env(:tzdata, :data_dir, release_base_path)
      assert release_base_path == Tzdata.Util.data_dir()

      release_path = Tzdata.EtsHolder.release_dir()
      assert :ok = File.mkdir_p!(release_path)

      release_name = "release_name"
      full_path = Path.join(release_path, Tzdata.EtsHolder.release_filename(release_name))

      {:ok, files} = File.ls(release_path)
      Enum.each(files, fn file -> File.rm!(Path.join(release_path, file)) end)

      assert ref = :ets.new(:etstab, [])

      assert true = :ets.insert(ref, {:a, 1})

      assert :ok = :ets.tab2file(ref, String.to_charlist(full_path))

      assert {:ok, new_ref} = Tzdata.EtsHolder.load_ets_table(release_name)

      assert [{:a, 1}] = :ets.lookup(new_ref, :a)
    end
  end
end
