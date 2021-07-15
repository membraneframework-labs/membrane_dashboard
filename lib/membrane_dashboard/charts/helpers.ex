defmodule Membrane.Dashboard.Charts.Helpers do
  @moduledoc """
  Module has functions useful for Membrane.Dashboard.Charts.Full and Membrane.Dashboard.Charts.Update.
  """

  import Membrane.Dashboard.Helpers
  require Logger

  @type rows_t :: [[term()]]
  @type series_type_t :: :simple | :cumulative | :changes_per_second
  @type interval_t :: [float()]
  @type series_t :: [{path :: String.t(), data :: list(integer())}]

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
  @spec group_rows_by_metrics(rows_t()) :: %{
          String.t() => rows_t()
        }
  def group_rows_by_metrics(rows) do
    Enum.group_by(
      rows,
      fn [_time, metric, _path, _value] -> metric end,
      fn [time, _metric, path, value] -> [time, path, value] end
    )
  end

  @doc """
  Calculates number of values that should appear in timeline's interval.

  For explanation on the interval see `timeline_interval/3`.
  """
  @spec timeline_interval_size(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          non_neg_integer()
  def timeline_interval_size(from, to, accuracy) do
    accuracy_in_seconds = to_seconds(accuracy)

    [from, to] = [
      apply_accuracy(from, accuracy_in_seconds),
      apply_accuracy(to, accuracy_in_seconds)
    ]

    floor((to - from) / accuracy_in_seconds) + 1
  end

  @doc """
  Time in uPlot have to be discrete, so every event from database will land in one specific timestamp from returned interval.
  Returns list of timestamps between `from` and `to` with difference between two neighboring values equal to `accuracy` milliseconds.

  ## Example

    iex> Membrane.Dashboard.Charts.Helpers.timeline_interval(1619776875855, 1619776875905, 10)
    [1619776875.8500001, 1619776875.8600001, 1619776875.8700001, 1619776875.88, 1619776875.89, 1619776875.9]

  """
  @spec timeline_interval(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: [float()]
  def timeline_interval(from, to, accuracy) do
    accuracy_in_seconds = to_seconds(accuracy)

    size = timeline_interval_size(from, to, accuracy)
    from = apply_accuracy(from, accuracy_in_seconds)

    for x <- 1..size, do: from + x * accuracy_in_seconds
  end

  @doc """
  Gets rows of TimescaleDB's `measurements` table and `interval` as list of timestamps.

  Returns list of tuples `{path, data}`, where `path` is pipeline element path and data is a list with
  values (one value for every timestamp in `interval`).
  """
  @spec to_simple_series(rows_t(), [float()]) :: series_t()
  def to_simple_series(rows, interval) do
    rows
    |> rows_to_data_by_paths()
    |> process_simple_series(interval)
  end

  @spec to_changes_per_second_series(rows_t(), interval_t(), [[integer()]], [String.t()]) ::
          series_t()
  def to_changes_per_second_series(rows, interval, old_data \\ nil, paths \\ nil) do
    initial_accumulators =
      if is_list(old_data) and is_list(paths) do
        get_changes_per_second_initial_accumulators(old_data, paths)
      else
        %{}
      end

    rows
    |> rows_to_data_by_paths()
    |> process_changes_per_second_series(interval, initial_accumulators)
  end

  @doc """
  Gets rows of TimescaleDB's `measurements` table, `interval` as list of timestamps, optional params `old_data` and `paths` and creates a cumulative series.

  Optional params:
  - old data - 2D list contatining metric data before update
  - paths - list of all paths that will be present in the new data

  Returns list of tuples `{path, data}`, where `path` is pipeline element path and data is a list with values (one value for every timestamp in `interval`).
  Data is altered in the way that every non-nil value is a a cumulative value of given metric since the beginning of live update.
  """
  def to_cumulative_series(rows, interval, old_data \\ nil, paths \\ nil) do
    data_by_paths = rows_to_data_by_paths(rows)

    initial_accumulators =
      cond do
        is_nil(old_data) and is_nil(paths) ->
          data_by_paths
          |> Enum.map(fn {path, _data} -> {path, 0} end)
          |> Enum.into(%{})

        is_list(old_data) and is_list(paths) ->
          get_initial_accumulators(old_data, paths)

        true ->
          raise "either neither or both 'paths' and 'old_data' must be set"
      end

    process_cumulative_series(data_by_paths, interval, initial_accumulators)
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

  defp process_simple_series(data_by_paths, interval) do
    data_by_paths
    |> Enum.map(fn {path, data} ->
      processed_data =
        data
        |> process_path_data(fn time, values -> {time, Enum.max(values, fn -> 0 end)} end)
        |> Enum.into(%{})

      {path, fill_with_nils(processed_data, interval)}
    end)
  end

  defp process_cumulative_series(data_by_paths, interval, initial_accumulators) do
    data_by_paths
    |> Enum.map(fn {path, data} ->
      processed_data =
        data
        |> process_path_data(fn time, values -> {time, Enum.sum(values)} end)
        |> Enum.into(%{})

      {path, fill_with_nils(processed_data, interval, initial_accumulators[path])}
    end)
  end

  defp process_changes_per_second_series(data_by_paths, interval, initial_accumulators) do
    data_by_paths
    |> Enum.map(fn {path, data} ->
      {init_sum, init_range} = Map.get(initial_accumulators, path, {0, []})

      {_sum, _range, processed_data} =
        data
        |> Enum.reduce({init_sum, init_range, []}, fn {time, value}, {sum_so_far, range, acc} ->
          {to_stay, to_drop} =
            range
            |> Enum.split_while(fn {old_time, _} ->
              time - old_time < 1.0
            end)

          sum_so_far = sum_so_far - (Enum.map(to_drop, &elem(&1, 1)) |> Enum.sum()) + value

          {sum_so_far, [{time, value} | to_stay], [{time, sum_so_far} | acc]}
        end)

      {path, fill_with_nils(Map.new(processed_data), interval)}
    end)
  end

  defp process_path_data([{time, value} | data], reduce_time_values) do
    data
    |> Enum.chunk_while(
      {time, [value]},
      fn
        {time, value}, {previous_time, acc} when time == previous_time ->
          {:cont, {time, [value | acc]}}

        {time, value}, {previous_time, acc} ->
          {:cont, reduce_time_values.(previous_time, acc), {time, [value]}}
      end,
      fn {time, values} ->
        {:cont, reduce_time_values.(time, values), nil}
      end
    )
  end

  # this looks like shit...
  def get_changes_per_second_initial_accumulators([interval | old_data], paths) do
    interval = Enum.reverse(interval)
    [last_time | _] = interval

    accumulators =
      old_data
      |> Enum.map(fn data ->
        acc =
          interval
          |> Enum.zip(Enum.reverse(data))
          |> Enum.take_while(fn {time, _value} ->
            last_time - time < 1.0
          end)
          |> Enum.reject(fn
            {_time, nil} -> true
            _ -> false
          end)

        {Enum.reduce(acc, 0, fn {_time, value}, acc -> value + acc end), acc}
      end)

    new_paths_count = length(paths) - length(accumulators)

    accumulators = accumulators ++ for _ <- 1..new_paths_count, do: {0, []}

    paths
    |> Enum.zip(accumulators)
    |> Enum.into(%{})
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
    path_data
    |> Enum.reject(&is_nil(&1))
    |> Enum.max(fn -> 0 end)
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

  defp fill_with_default(path_data, interval, default),
    do: interval |> Enum.map(&(path_data[&1] || default))

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
