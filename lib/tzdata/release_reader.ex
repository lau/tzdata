defmodule Tzdata.ReleaseReader do
  @moduledoc false

  def rules, do: simple_lookup_element(:rules) |> List.first()
  def zones, do: simple_lookup_element(:zones) |> List.first()
  def links, do: simple_lookup_element(:links) |> List.first()
  def zone_list, do: simple_lookup_element(:zone_list) |> List.first()
  def link_list, do: simple_lookup_element(:link_list) |> List.first()
  def zone_and_link_list, do: simple_lookup_element(:zone_and_link_list) |> List.first()
  def archive_content_length, do: simple_lookup_element(:archive_content_length) |> List.first()
  def release_version, do: simple_lookup_element(:release_version) |> List.first()
  def leap_sec_data, do: simple_lookup_element(:leap_sec_data) |> List.first()
  def by_group, do: simple_lookup_element(:by_group) |> List.first()
  def modified_at, do: simple_lookup_element(:modified_at) |> List.first()

  def simple_lookup_element(key) do
    :ets.lookup_element(
      table_name_for_current_release(),
      key,
      2,
      []
    )
  end

  def simple_lookup(key),
    do: :ets.lookup(table_name_for_current_release(), key)

  defp table_name_for_current_release(),
    do: current_release_from_table() |> table_name_for_release_name

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
    simple_lookup(:modified_at) |> Enum.any?()
  end

  defp do_periods_for_zone(zone) do
    zone
    |> lookup_periods_for_zone()
    |> Enum.sort_by(fn period -> elem(period, 1) |> delimiter_to_number() end)
  end

  defp lookup_periods_for_zone(zone) when is_binary(zone),
    do: simple_lookup(String.to_existing_atom(zone))

  defp lookup_periods_for_zone(_), do: []

  @doc !"""
       Hack which is useful for sorting periods. Delimiters can be integers representing
       gregorian seconds or :min or :max. By converting :min and :max to integers, they are
       easier to sort. It is assumed that the fake numbers they are converted to are far beyond
       numbers used.
       TODO: Instead of doing this, do the sorting before inserting. When reading from a bag the order
       should be preserved.
       """
  @very_high_number_representing_gregorian_seconds 9_315_537_984_000
  @low_number_representing_before_year_0 -1
  def delimiter_to_number(:min), do: @low_number_representing_before_year_0
  def delimiter_to_number(:max), do: @very_high_number_representing_gregorian_seconds
  def delimiter_to_number(integer) when is_integer(integer), do: integer

  defp current_release_from_table do
    :ets.lookup(:tzdata_current_release, :release_version) |> hd |> elem(1)
  end

  defp table_name_for_release_name(release_name) do
    "tzdata_rel_#{release_name}" |> String.to_atom()
  end

  def periods_for_zone_time_and_type(zone_name, time_point, time_type) do
    try do
      case do_periods_for_zone_time_and_type(zone_name, time_point, time_type) do
        {:ok, []} ->
          # If nothing was found, it could be that the zone name is not canonical.
          # E.g. "Europe/Jersey" which links to "Europe/London".
          # So we try with a link
          zone_name_to_use = links()[zone_name]

          case zone_name_to_use do
            nil -> {:ok, []}
            _ -> do_periods_for_zone_time_and_type(zone_name_to_use, time_point, time_type)
          end

        {:ok, list} ->
          {:ok, list}
      end
    rescue
      ArgumentError -> {:ok, []}
    end
  end

  @max_possible_periods_for_wall_time 2
  @max_possible_periods_for_utc 1
  def do_periods_for_zone_time_and_type(zone_name, time_point, :wall) do
    match_fun = [
      {{String.to_existing_atom(zone_name), :_, :"$1", :_, :_, :"$2", :_, :_, :_, :_},
       [
         {:andalso, {:orelse, {:"=<", :"$1", time_point}, {:==, :"$1", :min}},
          {:orelse, {:>, :"$2", time_point}, {:==, :"$2", :max}}}
       ], [:"$_"]}
    ]

    case :ets.select(
           current_release_from_table() |> table_name_for_release_name,
           match_fun,
           @max_possible_periods_for_wall_time
         ) do
      {ets_result, _} ->
        {:ok, ets_result}

      _ ->
        {:ok, []}
    end
  end

  def do_periods_for_zone_time_and_type(zone_name, time_point, :utc) do
    match_fun = [
      {{String.to_existing_atom(zone_name), :"$1", :_, :_, :"$2", :_, :_, :_, :_, :_},
       [
         {:andalso, {:orelse, {:"=<", :"$1", time_point}, {:==, :"$1", :min}},
          {:orelse, {:>, :"$2", time_point}, {:==, :"$2", :max}}}
       ], [:"$_"]}
    ]

    case :ets.select(
           current_release_from_table() |> table_name_for_release_name,
           match_fun,
           @max_possible_periods_for_utc
         ) do
      {ets_result, _} ->
        {:ok, ets_result}

      _ ->
        {:ok, []}
    end
  end
end
