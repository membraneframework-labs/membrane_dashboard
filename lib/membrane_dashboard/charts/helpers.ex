defmodule Membrane.Dashboard.Charts.Helpers do
  @moduledoc """
  Module has functions useful for Membrane.Dashboard.Charts.Full and Membrane.Dashboard.Charts.Update.
  """

  import Membrane.Dashboard.Helpers

  @type postgrex_result_rows_t :: [[term()] | binary()] | nil

  @doc """
  Returns query to select all measurements from database for given accuracy and time range (both in milliseconds).
  """
  @spec create_sql_query(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: String.t()
  def create_sql_query(accuracy, time_from, time_to) do
    accuracy_in_seconds = to_seconds(accuracy)

    """
      SELECT floor(extract(epoch from "time")/#{accuracy_in_seconds})*#{accuracy_in_seconds} AS time,
      metric,
      path,
      value
      FROM measurements m JOIN component_paths ep on m.component_path_id = ep.id
      WHERE
      time BETWEEN '#{parse_time(time_from)}' AND '#{parse_time(time_to)}'
      GROUP BY time, metric, path, value
      ORDER BY time
    """
  end

  @doc """
  Gets `time` as UNIX time in milliseconds and converts it to seconds.
  """
  @spec to_seconds(non_neg_integer()) :: float()
  def to_seconds(time),
    do: time / 1000

  @doc """
  Given rows from the result of `Postgrex.Result` structure, returns map: `%{metric => rows}`. 
  """
  @spec group_rows_by_metrics(postgrex_result_rows_t()) :: %{
          String.t() => postgrex_result_rows_t()
        }
  def group_rows_by_metrics(rows) do
    Enum.group_by(
      rows,
      fn [_time, metric, _path, _value] -> metric end,
      fn [time, _metric, path, value] -> [time, path, value] end
    )
  end

  @doc """
  Time in uPlot have to be discrete, so every event from database will land in one specific timestamp from returned interval.
  Returns list of timestamps between `from` and `to` with difference between two neighboring values equal to `accuracy` milliseconds.

  ## Example

    iex> Membrane.Dashboard.Charts.Helpers.create_interval(1619776875855, 1619776875905, 10)
    [1619776875.8500001, 1619776875.8600001, 1619776875.8700001, 1619776875.88, 1619776875.89, 1619776875.9]

  """
  @spec create_interval(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: [float()]
  def create_interval(from, to, accuracy) do
    accuracy_in_seconds = to_seconds(accuracy)

    [from, to] = [
      apply_accuracy(from, accuracy_in_seconds),
      apply_accuracy(to, accuracy_in_seconds)
    ]

    size = floor((to - from) / accuracy_in_seconds)

    for x <- 0..size, do: from + x * accuracy_in_seconds
  end

  @doc """
  Gets rows of TimescaleDB's `measurements` table and `interval` as list of timestamps.

  Returns list of tuples `{path, data}`, where `path` is pipeline element path and data is a list with
  values (one value for every timestamp in `interval`).
  """
  @spec to_series(postgrex_result_rows_t(), [float()]) :: [{String.t(), [non_neg_integer()]}]
  def to_series(rows, interval) do
    rows
    |> rows_to_data_by_paths()
    |> data_by_paths_to_series(interval)
  end

  @doc """
  Gets rows of TimescaleDB's `measurements` table, `interval` as list of timestamps, `mode` which is either `:full` or `:update` and two arguments needed when mode is set to `:update`:
  - old data - 2D list contatining metric data before update
  - paths - list of all paths that will be present in the new data

  Returns list of tuples `{path, data}`, where `path` is pipeline element path and data is a list with values (one value for every timestamp in `interval`). 
  Data is altered in the way that every non-nil value is a number of processed metric events from the beginning of live update.
  """
  @spec to_series(postgrex_result_rows_t(), [float()], atom(), [[non_neg_integer()]], [
          String.t()
        ]) :: [{String.t(), [non_neg_integer()]}]
  def to_series(rows, interval, mode, old_data \\ [], paths \\ []) do
    data_by_paths = rows_to_data_by_paths(rows)

    initial_accumulators =
      case mode do
        :full ->
          data_by_paths
          |> Enum.map(fn {path, _data} -> {path, 0} end)
          |> Enum.into(%{})

        :update ->
          get_initial_accumulators(old_data, paths)
      end

    data_by_paths_to_series(data_by_paths, interval, initial_accumulators)
  end

  # converts rows from `measurements` table to list of tuples `{path, data}`, where data is a list of tuples contatining timestamps and values
  defp rows_to_data_by_paths(rows) do
    Enum.group_by(rows, fn [_time, path, _value] -> path end, fn [time, _path, value] ->
      {time, value}
    end)
  end

  # converts every `data` from list of tuples `{path, data}` to list of integers (value for every timestamp from `interval`)
  # if `initial_accumulators` is not `nil`, data is altered in the way that every non-nil value is a number of processed metric events from the beginning of live update
  # `initial_accumulators` is a map %{path => initial number of processed metrics}
  defp data_by_paths_to_series(data_by_paths, interval, initial_accumulators \\ nil) do
    data_by_paths
    |> Enum.map(fn {path, data} ->
      data =
        data
        |> group_by_time()
        |> get_max_value_for_every_timestamp()
        |> Enum.into(%{})

      case initial_accumulators do
        nil -> {path, fill_with_nils(data, interval)}
        _ -> {path, fill_with_nils(data, interval, initial_accumulators[path])}
      end
    end)
  end

  # extracts initial numbers of processed metrics for update data from `old_data`
  defp get_initial_accumulators([_interval | old_data], paths) do
    accumulators =
      old_data
      |> Enum.map(&extract_max(&1))

    new_paths_count = length(paths) - length(accumulators)

    accumulators = accumulators ++ for _i <- 1..new_paths_count, do: 0

    Enum.zip(paths, accumulators)
    |> Enum.into(%{})
  end

  # performs `Enum.reduce/3` to get max value from a list while ignoring all `nils`
  defp extract_max(path_data) do
    Enum.reduce(
      path_data,
      0,
      fn value, acc ->
        case value do
          nil -> acc
          _ -> max(value, acc)
        end
      end
    )
  end

  # makes sure that border value read from user input has appropriate value to successfully match timestamps extracted from database
  defp apply_accuracy(time, accuracy),
    do: floor(time / (1000 * accuracy)) * accuracy

  # receives list of all tuples {time, value} for one pipeline path
  # groups values by timestamps (there can be more than one value per timestamp depending on `accuracy`)
  defp group_by_time(path_data),
    do: path_data |> Enum.group_by(fn {time, _value} -> time end, fn {_time, value} -> value end)

  # extracts one maximal value for every timestamp in passed pipeline path data
  defp get_max_value_for_every_timestamp(path_data),
    do: path_data |> Enum.map(fn {time, time_group} -> {time, Enum.max(time_group)} end)

  # to put data to uPlot, it is necessary to fill every gap in data by nils
  defp fill_with_nils(path_data, interval),
    do: interval |> Enum.map(&path_data[&1])

  # if passed `initial_accumulator`, then value is equal to number of processed metrics plus `initial_accumulator` at every non-nil point
  defp fill_with_nils(path_data, interval, initial_accumulator) do
    interval
    |> Enum.map_reduce(initial_accumulator, fn timestamp, accumulator ->
      extract_with_measurements_counting(path_data, timestamp, accumulator)
    end)
    |> elem(0)
  end

  # if there is a value for given `timestamp`, adds it to the `accumulator` and returns the sum
  # otherwise do not change `accumulator` and returns `nil`
  defp extract_with_measurements_counting(path_data, timestamp, accumulator) do
    if Map.has_key?(path_data, timestamp) do
      {accumulator + path_data[timestamp], accumulator + path_data[timestamp]}
    else
      {nil, accumulator}
    end
  end
end
