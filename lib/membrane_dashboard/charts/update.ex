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


  Steps needed for every chart to update data:
  1. Query database to get all data from last 5 seconds.
  2. Extract new paths (of pipeline elements) from the result of query (all paths that appeared for the first time in the last 5 seconds).
  3. Create list of uPlot Series objects with `label` attribute (as maps: `%{label: path_name}`). One map for every new path.
  4. Every path need to have value for every timestamp. Thus new series data for the time before update is filled with nils.
  5. Extract new data (data for all paths for last 5 seconds; as list of lists) from database query result.
  6. Truncate old data - delete its first 5 seconds (to maintain visibility of just last x minutes).
  7. Concatenate truncated old data and new series data - it creates full data for the time before update.
  8. Append new data to every path data.
  9. Create map (of type `update_data_t`) serializable to ChartData in ChartsHook.
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
  @spec query(Phoenix.LiveView.Socket.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, {[update_data_t()], [[[non_neg_integer()]]], [[String.t()]]}}
  def query(socket, time_from, time_to) do
    last_time_to = socket.assigns.time_to

    with {:ok, updated_data} <-
           query_recursively(
             socket.assigns.metrics,
             socket.assigns.paths,
             socket.assigns.data,
             socket.assigns.accuracy,
             time_from,
             last_time_to,
             time_to
           ) do
      {:ok, unzip3(updated_data)}
    end
  end

  # metrics, paths and old data are lists of the same size
  # one element of the list has information about one chart so one call of this function updates data for one chart
  defp query_recursively([], [], [], _accuracy, _time_from, _last_time_to, _time_to),
    do: {:ok, []}

  defp query_recursively(
         [metric | metrics],
         [metric_paths | paths],
         [metric_data | data],
         accuracy,
         time_from,
         last_time_to,
         time_to
       ) do
    with {:ok, metric_updated_data} <-
           one_chart_query(
             metric,
             metric_paths,
             metric_data,
             accuracy,
             time_from,
             last_time_to,
             time_to
           ),
         {:ok, updated_data} <-
           query_recursively(metrics, paths, data, accuracy, time_from, last_time_to, time_to) do
      {:ok, [metric_updated_data | updated_data]}
    end
  end

  # queries database and prepares data for one chart
  defp one_chart_query(metric, paths, old_data, accuracy, time_from, last_time_to, time_to) do
    update_from = last_time_to + accuracy

    with {:ok, %Postgrex.Result{rows: rows}} <-
           create_sql_query(accuracy, update_from, time_to, metric) |> Repo.query() do
      new_paths = get_new_paths(paths, rows)

      {new_series, new_series_data} =
        create_new_series(accuracy, time_from, last_time_to, new_paths)

      all_paths = paths ++ new_paths
      new_data = extract_new_data(accuracy, update_from, time_to, rows, all_paths)

      [old_timestamps | old_values] = old_data

      truncated_timestamps =
        old_timestamps
        |> Enum.drop_while(fn timestamp -> timestamp < to_seconds(time_from) end)

      to_drop = length(old_timestamps) - length(truncated_timestamps)

      truncated_old_values =
        old_values
        |> Enum.map(fn one_series_values -> Enum.drop(one_series_values, to_drop) end)

      truncated_old_data = [truncated_timestamps | truncated_old_values]

      updated_data = append_data(truncated_old_data ++ new_series_data, new_data)

      chart_data = %{
        series: new_series,
        data: updated_data
      }

      {:ok, {chart_data, updated_data, all_paths}}
    else
      {:error, _reason} -> {:error, "Cannot fetch update data for charts"}
    end
  end

  # returns paths from database query result which were not present before update
  defp get_new_paths(old_paths, rows) do
    rows
    |> Enum.map(fn [_time, path, _size] -> path end)
    |> Enum.uniq()
    |> Enum.filter(fn path -> not Enum.member?(old_paths, path) end)
  end

  # returns pair with:
  # - list of uPlot Series with labels (maps: %{label: path_name})
  # - list filled with nils for every new series (so list of lists)
  defp create_new_series(accuracy, time_from, time_to, new_paths) do
    series =
      new_paths
      |> Enum.map(fn path_name -> [{:label, path_name}] end)
      |> Enum.map(&Enum.into(&1, %{}))

    interval = create_interval(time_from, time_to, accuracy)

    all_nils = get_all_nils(interval)

    data =
      new_paths
      |> Enum.map(fn _path -> all_nils end)

    {series, data}
  end

  # creates list of values for every path in `paths`
  # such list consists of values for every timestamp between `time_from` and `time_to` with given `accuracy`
  # values are extracted from `rows` - result of database query
  # returns list of lists:
  # - first list contains timestamps
  # - next lists contains paths data
  defp extract_new_data(accuracy, time_from, time_to, rows, paths) do
    interval = create_interval(time_from, time_to, accuracy)

    data_by_paths =
      rows
      |> to_series(interval)
      |> Enum.into(%{})

    all_nils = get_all_nils(interval)

    data =
      paths
      |> Enum.map(fn path -> Map.get(data_by_paths, path, all_nils) end)

    [interval | data]
  end

  # returns list of nils: one `nil` for every timestamp in the `interval`
  defp get_all_nils(interval),
    do: for(_ <- 1..length(interval), do: nil)

  # appends new data for every series
  defp append_data([], []),
    do: []

  defp append_data([one_series_data | rest], [new_one_series_data | new_rest]),
    do: [one_series_data ++ new_one_series_data | append_data(rest, new_rest)]

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
