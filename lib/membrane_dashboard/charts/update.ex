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
  3. Every path needs to have a value for every timestamp thus new data series must be filled with nils until the first measurement timestamp.
  4. Extract new data (data for all paths for the last 5 seconds; as a list of lists) from the database query result.
  5. Truncate old data - delete its first 5 seconds (to maintain visibility of just last x minutes).
  6. Concatenate truncated old data and new series data - it creates full data for the time before update.
  7. Append new data to every path data.
  8. Create map (of type `update_data_t`) that is serializable to ChartData in ChartsHook.
  """

  import Membrane.Dashboard.Charts.Helpers

  alias Membrane.Dashboard.Charts
  alias Membrane.Dashboard.Charts.Context

  @doc """
  Returns:
    - update data for uPlot, where new data is from between `time_from` and `time_to`. Consists of new series and full data for charts;
    - full data as 3d list;
    - list of all paths.
  """
  @spec query(Context.t()) :: Charts.chart_query_result_t()
  def query(
        %Context{time_from: time_from, time_to: time_to, metric: metric, accuracy: accuracy} =
          context
      ) do
    %Context{
      paths_mapping: old_paths_mapping,
      data: data,
      accumulators: accumulator,
      latest_time: last_time_to
    } = context

    update_from = last_time_to + accuracy

    case query_measurements(update_from, time_to, metric, accuracy) do
      {:ok, rows, new_paths_mapping} ->
        total_new_paths = new_paths_count(old_paths_mapping, rows)

        joined_paths_mapping = Map.merge(old_paths_mapping, new_paths_mapping)

        # Create data for newly added series
        new_series_data = create_new_series(accuracy, time_from, last_time_to, total_new_paths)

        {new_data, accumulator} =
          extract_new_data(
            metric,
            accumulator,
            accuracy,
            update_from,
            time_to,
            rows,
            joined_paths_mapping
          )

        # Truncate old data so that we stay within a proper time range
        # NOTE: first row of data field consists of timestamps and a single timestamp denotes a column to which all values will belong
        [old_timestamps | old_values] = data.data

        truncated_timestamps =
          Enum.drop_while(old_timestamps, fn timestamp -> timestamp < to_seconds(time_from) end)

        to_drop = length(old_timestamps) - length(truncated_timestamps)

        truncated_old_values =
          Enum.map(old_values, fn one_series_values -> Enum.drop(one_series_values, to_drop) end)

        truncated_old_data = [truncated_timestamps | truncated_old_values]
        updated_data = append_data(truncated_old_data ++ new_series_data, new_data)

        chart_data = %{
          # this is just wrong...
          series:
            joined_paths_mapping
            |> Enum.sort_by(fn {key, _value} -> key end)
            |> Enum.map(fn {_key, value} -> %{label: value} end),
          data: updated_data
        }

        {:ok, {chart_data, joined_paths_mapping, accumulator}}

      :error ->
        {:error, "Cannot fetch update data for charts"}
    end
  end

  # returns paths from database query result which were not present before update
  defp new_paths_count(old_paths, rows) do
    old_ids =
      old_paths
      |> Map.keys()
      |> MapSet.new()

    rows
    |> MapSet.new(fn [_time, path_id, _size] -> path_id end)
    |> MapSet.difference(old_ids)
    |> MapSet.size()
  end

  # returns pair with:
  # - list of uPlot Series with labels (maps: %{label: path_name})
  # - list filled with nils for every new series (so list of lists)
  defp create_new_series(accuracy, time_from, time_to, new_paths) do
    nils = for _ <- 1..timeline_interval_size(time_from, time_to, accuracy), do: nil
    data = for _ <- 1..new_paths, do: nils

    data
  end

  # creates list of values for every path in `paths`
  # such list consists of values for every timestamp between `time_from` and `time_to` with given `accuracy`
  # values are extracted from `rows` - result of database query
  # values for metrics `caps` and `event` are altered - they show sum of processed metrics from the beginning of live update
  # returns list of lists:
  # - first list contains timestamps
  # - next lists contains paths data
  defp extract_new_data(metric, accumulator, accuracy, time_from, time_to, rows, paths_mapping) do
    interval = timeline_interval(time_from, time_to, accuracy)

    {data_by_paths, accumulator} =
      cond do
        metric in ["caps", "event"] ->
          to_cumulative_series(rows, interval, accumulator)

        metric in ["buffer", "bitrate"] ->
          to_changes_per_second_series(rows, interval, accumulator)

        true ->
          to_simple_series(rows, interval)
      end
      |> Enum.unzip()

    nils = for _ <- 1..length(interval), do: nil

    accumulator_ids = Enum.map(data_by_paths, fn {path_id, _data} -> path_id end)

    mapped_data = Map.new(data_by_paths)

    path_ids =
      paths_mapping
      |> Map.keys()
      |> Enum.sort()

    data = Enum.map(path_ids, &Map.get(mapped_data, &1, nils))

    {[interval | data], Enum.zip(accumulator_ids, accumulator) |> Map.new()}
  end

  # appends new data for every series
  defp append_data(old_series, new_series) do
    old_series
    |> Enum.zip(new_series)
    |> Enum.map(fn {old, new} -> old ++ new end)
  end
end
