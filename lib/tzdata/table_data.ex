defmodule Tzdata.TableData do
  @moduledoc false
#  @moduledoc """
#  Provides data about which timezones to use for which area. This is based
#  on the information in the zone1970.tab part of the IANA tz database.
#
#  The tz database contains a lot of legacy timezones that are not needed for most users.
#
#  The database file says:
#  > This table is intended as an aid for users, to help
#  > them select time zone data entries appropriate for their practical needs.
#  > It is not intended to take or endorse any position on legal or territorial claims.
#  """
#
#  file_read = Tzdata.TableParser.read_file |> Enum.to_list
#
#  timezones = Enum.map(file_read, &(&1["timezone"]))
#
#  @doc """
#  Returns a list of all timezones found in the zone1970.tab file
#  """
#  def timezones do
#    unquote(Macro.escape(timezones))
#  end
#
#  country_codes = file_read
#      |> Enum.flat_map(&(&1["country_codes"]))
#      |> Enum.uniq
#      |> Enum.sort
#
#  @doc """
#  Returns a list of all country_codes found in the zone1970.tab file
#  """
#  def country_codes do
#    unquote(Macro.escape(
#      country_codes
#    ))
#  end
#
#  keyword_dict_by_country_codes = file_read |> Enum.flat_map(fn entry ->
#        Enum.map(entry["country_codes"], &({&1|>String.to_atom, entry}))
#      end)
#
#  @doc """
#  Provides entries with timezones that are in use in the country that
#  corresponds to the `country_code` argument.
#  """
#  Enum.each country_codes, fn (country_code) ->
#    def for_country_code(unquote(country_code)) do
#      unquote(Macro.escape(
#        Keyword.get_values keyword_dict_by_country_codes,
#                           String.to_atom(country_code)
#      ))
#    end
#  end
#  def for_country_code(_), do: :country_code_not_found
#
#  @doc """
#  Provides the entry for the `timezone` given as argument.
#  """
#  Enum.each timezones, fn (timezone) ->
#    def for_timezone(unquote(timezone)) do
#      unquote(Macro.escape(
#        Enum.find(file_read, fn(elem) -> elem["timezone"] == timezone end )
#      ))
#    end
#  end
#  def for_timezone(_), do: :timezone_not_found
end
