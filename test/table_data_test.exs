defmodule TableDataTest do
  use ExUnit.Case, async: true
  alias Tzdata.TableData

  test "list of timezones" do
    assert TableData.timezones |> Enum.member?("Europe/London")
  end

  test "list of country codes" do
    assert TableData.country_codes |> Enum.member?("UY")
  end

  test "timezone entries for country code" do
    assert TableData.for_country_code("UY") == [%{"comments" => "", "country_codes" => ["UY"], "latlong" => "-3453-05611",
              "timezone" => "America/Montevideo"}]
  end

  test "entry for timezone" do
    assert TableData.for_timezone("America/Montevideo") == %{"comments" => "", "country_codes" => ["UY"], "latlong" => "-3453-05611",
             "timezone" => "America/Montevideo"}
  end
end
