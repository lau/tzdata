defmodule Tzdata.ReleaseReader do
  def rules,                  do: simple_lookup(:rules) |> hd |> elem(1)
  def zones,                  do: simple_lookup(:zones) |> hd |> elem(1)
  def links,                  do: simple_lookup(:links) |> hd |> elem(1)
  def zone_list,              do: simple_lookup(:zone_list) |> hd |> elem(1)
  def link_list,              do: simple_lookup(:link_list) |> hd |> elem(1)
  def zone_and_link_list,     do: simple_lookup(:zone_and_link_list) |> hd |> elem(1)
  def archive_content_length, do: simple_lookup(:archive_content_length) |> hd |> elem(1)
  def release_version,        do: simple_lookup(:release_version) |> hd |> elem(1)
  def leap_sec_data,          do: simple_lookup(:leap_sec_data) |> hd |> elem(1)
  def by_group,               do: simple_lookup(:by_group) |> hd |> elem(1)
  def modified_at,            do: simple_lookup(:modified_at) |> hd |> elem(1)
  defp simple_lookup(key) do
    :ets.lookup(current_release_from_table() |> table_name_for_release_name, key)
  end
  def zone(zone_name) do
    {:ok, zones()[zone_name]}
  end
  def rules_for_name(rules_name) do
    {:ok, rules()[rules_name]}
  end
  def periods_for_zone_or_link(zone) do
    if Enum.member?(zone_list(), zone) do
      {:ok, do_periods_for_zone(zone)}
    else
      case Enum.member?(link_list(), zone) do
        true -> periods_for_zone_or_link(links()[zone])
        _ -> {:error, :not_found}
      end
    end
  end

  def has_modified_at? do
    simple_lookup(:modified_at) != []
  end

  defp do_periods_for_zone(zone) do
    case lookup_periods_for_zone(zone) do
      periods when is_list(periods) -> periods
        |> Enum.sort_by(fn period -> elem(period, 1) |> delimiter_to_number() end)
      _ -> nil
    end
  end
  defp lookup_periods_for_zone(zone) when is_binary(zone), do: simple_lookup(String.to_atom zone)
  defp lookup_periods_for_zone(_), do: []

  @doc !"""
  Hack which is useful for sorting periods. Delimiters can be integers representing
  gregorian seconds or :min or :max. By converting :min and :max to integers, they are
  easier to sort. It is assumed that the fake numbers they are converted to are far beyond
  numbers used.
  TODO: Instead of doing this, do the sorting before inserting. When reading from a bag the order
  should be preserved.
  """
  @very_high_number_representing_gregorian_seconds 9315537984000
  @low_number_representing_before_year_0 -1
  defp delimiter_to_number(:min), do: @low_number_representing_before_year_0
  defp delimiter_to_number(:max), do: @very_high_number_representing_gregorian_seconds
  defp delimiter_to_number(integer) when is_integer(integer), do: integer

  defp current_release_from_table do
    :ets.lookup(:tzdata_current_release, :release_version) |> hd |> elem(1)
  end

  defp table_name_for_release_name(release_name) do
    "tzdata_rel_#{release_name}" |> String.to_atom
  end
end
