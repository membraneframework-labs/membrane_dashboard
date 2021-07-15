defmodule Membrane.Dashboard.Charts.Update do
  @moduledoc """
  Module responsible for preparing data for uPlot charts when they are being updated.

  Example (showing last 5 minutes of one chart data)

  -305s  -300s                                -5s        now
     _____________________________________________________
    |                                          |          |
    |                Old data                  |          |
    |__________________________________________| New data |
           |          New series data          |          |
           |___________________________________|__________|
                             |
                             |
                             |
                             V
            ______________________________________________
           |                                              |
           |                                              |
           |               Updated data                   |
           |                                              |
           |______________________________________________|


  Firstly, queries the database to get all the data from the last 5 seconds. Then applies the following steps for every chart to update the data:
  1. Extract new paths (of pipeline elements) from the result of the query (all paths that appeared for the first time in the last 5 seconds).
  2. Create a list of uPlot Series objects with the `label` attribute (as maps: `%{label: path_name}`). One map for every new path.
  3. Every path needs to have a value for every timestamp. Thus new series data for the time before update is filled with nils.
  4. Extract new data (data for all paths for last 5 seconds; as a list of lists) from the database query result.
  5. Truncate old data - delete its first 5 seconds (to maintain visibility of just last x minutes).
  6. Concatenate truncated old data and new series data - it creates full data for the time before update.
  7. Append new data to every path data.
  8. Create map (of type `update_data_t`) serializable to ChartData in ChartsHook.
  """

  import Membrane.Dashboard.Charts.Helpers

  alias Membrane.Dashboard.Repo

  @type update_data_t :: %{
          series: [%{label: String.t()}],
          data: [[integer()]]
        }

  @doc """
  Returns:
    - update data for uPlot, where new data is from between `time_from` and `time_to`. Consists of new series and full data for charts;
    - full data as 3d list;
    - list of all paths.
  """
  @spec query(assigns :: map(), non_neg_integer(), non_neg_integer()) ::
          {:ok, {[update_data_t()], [[[non_neg_integer()]]], [[String.t()]]}}
  def query(assigns, time_from, time_to) do
    last_time_to = assigns.time_to
    update_from = last_time_to + assigns.accuracy

    with {:ok, %Postgrex.Result{rows: rows}} <-
           create_sql_query(assigns.accuracy, update_from, time_to) |> Repo.query() do
      rows_by_metrics = group_rows_by_metrics(rows)

      updated_data =
        query_recursively(
          assigns.metrics,
          rows_by_metrics,
          assigns.paths,
          assigns.data,
          assigns.accuracy,
          time_from,
          update_from,
          last_time_to,
          time_to
        )
        |> unzip3()

      {:ok, updated_data}
    else
      {:error, _reason} -> {:error, "Cannot fetch update data for charts"}
    end
  end

  # metrics, paths and old data are lists of the same size
  # one element of the list has information about one chart so one call of this function updates data for one chart
  defp query_recursively(
         [],
         _rows_by_metrics,
         [],
         [],
         _accuracy,
         _time_from,
         _update_from,
         _last_time_to,
         _time_to
       ),
       do: []

  defp query_recursively(
         [metric | metrics],
         rows_by_metrics,
         [metric_paths | paths],
         [metric_data | data],
         accuracy,
         time_from,
         update_from,
         last_time_to,
         time_to
       ) do
    metric_updated_data =
      one_chart_query(
        metric,
        Map.get(rows_by_metrics, metric, []),
        metric_paths,
        metric_data,
        accuracy,
        time_from,
        update_from,
        last_time_to,
        time_to
      )

    updated_data =
      query_recursively(
        metrics,
        rows_by_metrics,
        paths,
        data,
        accuracy,
        time_from,
        update_from,
        last_time_to,
        time_to
      )

    [metric_updated_data | updated_data]
  end

  # prepares data for one chart
  defp one_chart_query(
         metric,
         rows,
         paths,
         old_data,
         accuracy,
         time_from,
         update_from,
         last_time_to,
         time_to
       ) do
    new_paths = get_new_paths(paths, rows)
    all_paths = paths ++ new_paths

    {new_series, new_series_data} =
      create_new_series(accuracy, time_from, last_time_to, new_paths)

    new_data = extract_new_data(metric, old_data, accuracy, update_from, time_to, rows, all_paths)

    [old_timestamps | old_values] = old_data

    truncated_timestamps =
      Enum.drop_while(old_timestamps, fn timestamp -> timestamp < to_seconds(time_from) end)

    to_drop = length(old_timestamps) - length(truncated_timestamps)

    truncated_old_values =
      Enum.map(old_values, fn one_series_values -> Enum.drop(one_series_values, to_drop) end)

    truncated_old_data = [truncated_timestamps | truncated_old_values]
    updated_data = append_data(truncated_old_data ++ new_series_data, new_data)

    chart_data = %{
      series: new_series,
      data: updated_data
    }

    {chart_data, updated_data, all_paths}
  end

  # returns paths from database query result which were not present before update
  defp get_new_paths(old_paths, rows) do
    rows
    |> MapSet.new(fn [_time, path, _size] -> path end)
    |> MapSet.difference(MapSet.new(old_paths))
    |> MapSet.to_list()
  end

  # returns pair with:
  # - list of uPlot Series with labels (maps: %{label: path_name})
  # - list filled with nils for every new series (so list of lists)
  defp create_new_series(accuracy, time_from, time_to, new_paths) do
    nils = for _ <- 1..timeline_interval_size(time_from, time_to, accuracy), do: nil
    data = for _ <- 1..length(new_paths), do: nils

    series =
      new_paths
      |> Enum.map(&%{label: &1})

    {series, data}
  end

  # creates list of values for every path in `paths`
  # such list consists of values for every timestamp between `time_from` and `time_to` with given `accuracy`
  # values are extracted from `rows` - result of database query
  # values for metrics `caps` and `event` are altered - they show sum of processed metrics from the beginning of live update
  # returns list of lists:
  # - first list contains timestamps
  # - next lists contains paths data
  defp extract_new_data(metric, old_data, accuracy, time_from, time_to, rows, paths) do
    interval = timeline_interval(time_from, time_to, accuracy)

    data_by_paths =
      cond do
        metric in ["caps", "event"] ->
          to_cumulative_series(rows, interval, old_data, paths)

        metric in ["buffer", "bitrate"] ->
          to_changes_per_second_series(rows, interval, old_data, paths)

        true ->
          to_simple_series(rows, interval)
      end
      |> Enum.into(%{})

    nils = for _ <- 1..length(interval), do: nil
    data = Enum.map(paths, &Map.get(data_by_paths, &1, nils))

    [interval | data]
  end

  # appends new data for every series
  defp append_data([], []),
    do: []

  # defp append_data([one_series_data | rest], [new_one_series_data | new_rest]),
  #   do: [one_series_data ++ new_one_series_data | append_data(rest, new_rest)]

  defp append_data(old_series, new_series),
    do: Enum.zip(old_series, new_series) |> Enum.map(fn {old, new} -> old ++ new end)

  # from [{a1, b1, c1}, {a2, b2, c2}, ...] to {[a1, a2, ...], [b1, b2, ...], [c1, c2, ...]}
  defp unzip3([]),
    do: {[], [], []}

  defp unzip3(list),
    do: :lists.reverse(list) |> unzip3([], [], [])

  defp unzip3([{el1, el2, el3} | reversed_list], list1, list2, list3),
    do: unzip3(reversed_list, [el1 | list1], [el2 | list2], [el3 | list3])

  defp unzip3([], list1, list2, list3),
    do: {list1, list2, list3}
end
