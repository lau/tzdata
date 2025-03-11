defmodule Tzdata.ReleaseReader.Behavior do
  @callback rules() :: any()
  @callback zones() :: any()
  @callback links() :: any()
  @callback zone_list() :: any()
  @callback link_list() :: any()
  @callback zone_and_link_list() :: any()
  @callback archive_content_length() :: any()
  @callback release_version() :: any()
  @callback leap_sec_data() :: any()
  @callback by_group() :: any()
  @callback modified_at() :: any()
  @callback zone(zone_name :: String.t()) :: {:ok, any()} | {:error, :not_found}
  @callback rules_for_name(rules_name :: String.t()) :: {:ok, any()} | {:error, :not_found}
  @callback periods_for_zone_or_link(zone :: String.t()) :: {:ok, any()} | {:error, :not_found}
  @callback has_modified_at?() :: boolean()
  @callback delimiter_to_number(:min | :max | integer) :: any
  @callback periods_for_zone_time_and_type(zone_name :: String.t(), time_point :: any(), time_type :: any()) :: {:ok, any()} | {:error, :not_found}

end

defmodule Tzdata.ReleaseReader do

  @behaviour Tzdata.ReleaseReader.Behavior
  @provider Application.compile_env(:tzdata, :release_reader, Tzdata.ReleaseReader.Ets)

  @impl true
  defdelegate rules(), to: @provider

  @impl true
  defdelegate zones(), to: @provider

  @impl true
  defdelegate links(), to: @provider

  @impl true
  defdelegate zone_list(), to: @provider

  @impl true
  defdelegate link_list(), to: @provider

  @impl true
  defdelegate zone_and_link_list(), to: @provider

  @impl true
  defdelegate archive_content_length(), to: @provider

  @impl true
  defdelegate release_version(), to: @provider

  @impl true
  defdelegate leap_sec_data(), to: @provider

  @impl true
  defdelegate by_group(), to: @provider

  @impl true
  defdelegate modified_at(), to: @provider

  @impl true
  defdelegate zone(zone_name), to: @provider

  @impl true
  defdelegate rules_for_name(rules_name), to: @provider

  @impl true
  defdelegate periods_for_zone_or_link(zone), to: @provider

  @impl true
  defdelegate has_modified_at?(), to: @provider

  @impl true
  defdelegate delimiter_to_number(), to: @provider

  @impl true
  defdelegate periods_for_zone_time_and_type(zone_name, time_point, time_type), to: @provider
end

defmodule Tzdata.ReleaseReader.Ets do
  @behaviour Tzdata.ReleaseReader.Behavior
  @moduledoc false

  @impl true
  def rules,                  do: simple_lookup(:rules) |> hd |> elem(1)

  @impl true
  def zones,                  do: simple_lookup(:zones) |> hd |> elem(1)

  @impl true
  def links,                  do: simple_lookup(:links) |> hd |> elem(1)

  @impl true
  def zone_list,              do: simple_lookup(:zone_list) |> hd |> elem(1)

  @impl true
  def link_list,              do: simple_lookup(:link_list) |> hd |> elem(1)

  @impl true
  def zone_and_link_list,     do: simple_lookup(:zone_and_link_list) |> hd |> elem(1)

  @impl true
  def archive_content_length, do: simple_lookup(:archive_content_length) |> hd |> elem(1)

  @impl true
  def release_version,        do: simple_lookup(:release_version) |> hd |> elem(1)

  @impl true
  def leap_sec_data,          do: simple_lookup(:leap_sec_data) |> hd |> elem(1)

  @impl true
  def by_group,               do: simple_lookup(:by_group) |> hd |> elem(1)

  @impl true
  def modified_at,            do: simple_lookup(:modified_at) |> hd |> elem(1)

  def simple_lookup(key) do
    :ets.lookup(current_release_from_table() |> table_name_for_release_name, key)
  end

  @impl true
  def zone(zone_name) do
    {:ok, zones()[zone_name]}
  end

  @impl true
  def rules_for_name(rules_name) do
    {:ok, rules()[rules_name]}
  end

  @impl true
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

  @impl true
  def has_modified_at? do
    simple_lookup(:modified_at) != []
  end

  @impl true
  defp do_periods_for_zone(zone) do
    case lookup_periods_for_zone(zone) do
      periods when is_list(periods) ->
        periods
        |> Enum.sort_by(fn period -> elem(period, 1) |> delimiter_to_number() end)

      _ ->
        nil
    end
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
  @impl true
  def delimiter_to_number(:min), do: @low_number_representing_before_year_0
  def delimiter_to_number(:max), do: @very_high_number_representing_gregorian_seconds
  def delimiter_to_number(integer) when is_integer(integer), do: integer

  def current_release_from_table do
    :ets.lookup(:tzdata_current_release, :release_version) |> hd |> elem(1)
  end

  def table_name_for_release_name(release_name) do
    "tzdata_rel_#{release_name}" |> String.to_atom()
  end

  @impl true
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

  @impl true
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


defmodule Tzdata.ReleaseReader.Pt do
  @behaviour Tzdata.ReleaseReader.Behavior
  @provider Application.compile_env(:tzdata, :release_reader, Tzdata.ReleaseReader.Ets)

  def force_load() do
    release = Tzdata.ReleaseReader.Ets.current_release_from_table()
    table = Tzdata.ReleaseReader.Ets.table_name_for_release_name(release)
    c = :ets.tab2list(:tzdata_rel_2023c)
        |> Enum.group_by(& elem(&1, 0))
    k = do_term_name_for_release_name(release)
    :persistent_term.put(k, c)
    :persistent_term.put({:tz_cache_meta, :current_release}, k)
  end

  defp do_term_name_for_release_name(release) do
    {:tz_cache, String.to_atom(release)}
  end
  def term_name_for_release_name(release) do
    {:tz_cache, String.to_existing_atom(release)}
  end

  defp do_queue_init() do
    # todo single process controller
    force_load()
  end

  defp current_release() do
    with :init <- :persistent_term.get({:tz_cache_meta, :current_release}, :init) do
      do_queue_init()
      :fallback
    end
  end

  defp tz_cache(release) do
    with :init <- :persistent_term.get(:tz_cache__current_release, :init) do
      :fallback
    end
  end


  @impl true
  def rules,                  do: simple_lookup(:rules) |> hd |> elem(1)

  @impl true
  def zones,                  do: simple_lookup(:zones) |> hd |> elem(1)

  @impl true
  def links,                  do: simple_lookup(:links) |> hd |> elem(1)

  @impl true
  def zone_list,              do: simple_lookup(:zone_list) |> hd |> elem(1)

  @impl true
  def link_list,              do: simple_lookup(:link_list) |> hd |> elem(1)

  @impl true
  def zone_and_link_list,     do: simple_lookup(:zone_and_link_list) |> hd |> elem(1)

  @impl true
  def archive_content_length, do: simple_lookup(:archive_content_length) |> hd |> elem(1)

  @impl true
  def release_version,        do: simple_lookup(:release_version) |> hd |> elem(1)

  @impl true
  def leap_sec_data,          do: simple_lookup(:leap_sec_data) |> hd |> elem(1)

  @impl true
  def by_group,               do: simple_lookup(:by_group) |> hd |> elem(1)

  @impl true
  def modified_at,            do: simple_lookup(:modified_at) |> hd |> elem(1)

  defp simple_lookup(key) do
    with %{^key => v} <- tz_cache(current_release)  do
      v
    else
      :fallback -> Tzdata.ReleaseReader.Ets.simple_lookup(key)
      _ -> nil
    end
  end



  @impl true
  def zone(zone_name) do
    {:ok, zones()[zone_name]}
  end

  @impl true
  def rules_for_name(rules_name) do
    {:ok, rules()[rules_name]}
  end


  @impl true
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

  @impl true
  def has_modified_at? do
    simple_lookup(:modified_at) != []
  end

  @impl true
  defp do_periods_for_zone(zone) do
    case lookup_periods_for_zone(zone) do
      periods when is_list(periods) ->
        periods
        |> Enum.sort_by(fn period -> elem(period, 1) |> delimiter_to_number() end)

      _ ->
        nil
    end
  end

  defp lookup_periods_for_zone(zone) when is_binary(zone),
       do: simple_lookup(String.to_existing_atom(zone))

  defp lookup_periods_for_zone(_), do: []

  @impl true
  defp do_periods_for_zone(zone) do
    case lookup_periods_for_zone(zone) do
      periods when is_list(periods) ->
        periods
        |> Enum.sort_by(fn period -> elem(period, 1) |> delimiter_to_number() end)

      _ ->
        nil
    end
  end

  defp lookup_periods_for_zone(zone) when is_binary(zone),
       do: simple_lookup(String.to_existing_atom(zone))

  defp lookup_periods_for_zone(_), do: []



  @impl true
  def has_modified_at? do
    simple_lookup(:modified_at) != []
  end

  @impl true
  defdelegate delimiter_to_number(d), to: Tzdata.ReleaseReader.Ets

  @impl true
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

  @impl true
  @max_possible_periods_for_wall_time 2
  @max_possible_periods_for_utc 1
  def do_periods_for_zone_time_and_type(zone_name, time_point, :wall) do
    zone_atom = String.to_existing_atom(zone_name)
    Enum.reduce(simple_lookup(zone_atom), [], fn
      ({^zone_atom, _, t1, _, _, t2, _, _, _, _} = element, acc) when (t1 <= time_point or t1 == :min) and (t2 > time_point or t2 == :max) ->
        if length(acc) < @max_possible_periods_for_wall_time do
          [element | acc]
        else
          acc
        end
      _, acc ->
        acc
    end)
    |> then(& {:ok, Enum.reverse(&1)})
  end

  def do_periods_for_zone_time_and_type(zone_name, time_point, :utc) do
    zone_atom = String.to_existing_atom(zone_name)
    Enum.reduce(simple_lookup(zone_atom), [], fn
      ({^zone_atom, t1, _, _, t2, _, _, _, _, _} = element, acc) when (t1 <= time_point or t1 == :min) and (t2 > time_point or t2 == :max) ->
        if length(acc) < @max_possible_periods_for_wall_time do
          [element | acc]
        else
          acc
        end
      _, acc ->
        acc
    end)
    |> then(& {:ok, Enum.reverse(&1)})
  end
end
