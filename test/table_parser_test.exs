defmodule TableParserTest do
  use ExUnit.Case, async: true
  alias Tzdata.TableParser

  test "should process file and return list of elements with comments, timezone, country codes, latlong" do
    processed = TableParser.read_file |> Enum.to_list
    assert hd(processed)["comments"] != nil
    assert hd(processed)["timezone"] != nil
    assert length(hd(processed)["country_codes"]) >= 1
    assert hd(processed)["latlong"] != nil
  end
end
