defmodule Tzdata.TableData do
  file_read = Tzdata.TableParser.read_file |> Enum.to_list

  timezones = Enum.map(file_read, &(&1["timezone"]))

  @doc """
  Returns a list of all timezones found in the zone1970.tab file
  """
  def timezones do
    unquote(Macro.escape(timezones))
  end

  country_codes = file_read
      |> Enum.flat_map(&(&1["country_codes"]))
      |> Enum.uniq
      |> Enum.sort

  @doc """
  Returns a list of all country_codes found in the zone1970.tab file
  """
  def country_codes do
    unquote(Macro.escape(
      country_codes
    ))
  end

  #by_timezone = file_read |> Enum.group_by(&(&1["timezone"]))

  keyword_dict_by_country_codes = file_read |> Enum.flat_map(fn entry ->
        Enum.map(entry["country_codes"], &({&1|>String.to_atom, entry}))
      end)

  Enum.each country_codes, fn (country_code) ->
    def for_country_code(unquote(country_code)) do
      unquote(Macro.escape(
        Keyword.get_values keyword_dict_by_country_codes,
                           String.to_atom(country_code)
      ))
    end
  end
  def for_country_code(_), do: :country_code_not_found

  Enum.each timezones, fn (timezone) ->
    def for_timezone(unquote(timezone)) do
      unquote(Macro.escape(
        Enum.find(file_read, fn(elem) -> elem["timezone"] == timezone end )
      ))
    end
  end
  def for_timezone(_), do: :timezone_not_found
end
