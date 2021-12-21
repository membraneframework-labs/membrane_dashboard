defmodule Membrane.Dashboard.Charts.Helpers do
  @moduledoc """
  Module has functions useful for Membrane.Dashboard.Charts.Full and Membrane.Dashboard.Charts.Update.
  """

  import Membrane.Dashboard.Helpers
  import Ecto.Query, only: [from: 2]

  alias Membrane.Dashboard.Repo

  require Logger

  @type rows_t :: [[term()]]
  @type interval_t :: [float()]
  @type series_t :: [{{path :: String.t(), data :: list(integer())}, accumulator :: any()}]

  @doc """
  Queries all measurements for given time range, metric and accuracy and returns them together
  with mapping of its component path ids to the path strings.
  """
  @spec query_measurements(non_neg_integer(), non_neg_integer(), String.t(), non_neg_integer()) ::
          {:ok, rows_t(), %{non_neg_integer() => String.t()}} | :error
  def query_measurements(time_from, time_to, metric, accuracy) do
    with {:ok, %Postgrex.Result{rows: measurements_rows}} <-
           Repo.query(measurements_query(time_from, time_to, metric, accuracy)),
         component_path_rows <- Repo.all(component_paths_query(measurements_rows)) do
      components_mapping = Map.new(component_path_rows)

      {:ok, measurements_rows, components_mapping}
    else
      error ->
        Logger.error(
          "Encountered error while querying database for charts data: #{inspect(error)}"
        )

        :error
    end
  end

  defp measurements_query(time_from, time_to, metric, accuracy) do
    accuracy_in_seconds = to_seconds(accuracy)

    """
      SELECT
      floor(extract(epoch from "time")/#{accuracy_in_seconds})*#{accuracy_in_seconds} AS time,
      component_path_id,
      value
      FROM measurements
      WHERE time BETWEEN '#{parse_time(time_from)}' AND '#{parse_time(time_to)}' AND metric = '#{metric}'
      ORDER BY time;
    """
  end

  defp component_paths_query(measurements_rows) do
    ids =
      measurements_rows
      |> Enum.map(fn [_time, path_id | _] -> path_id end)
      |> Enum.uniq()

    from(cp in "component_paths", where: cp.id in ^ids, select: {cp.id, cp.path})
  end

  @doc """
  Gets `time` as UNIX time in milliseconds and converts it to seconds.
  """
  @spec to_seconds(non_neg_integer()) :: float()
  def to_seconds(time),
    do: time / 1000

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
  Returns list of timestamps between `from` and `to` where two neighboring values differ by `accuracy` milliseconds.

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
  Creates a simple series which have unchanged values per every interval timestamp.
  """
  @spec to_simple_series(rows_t(), [float()]) :: series_t()
  def to_simple_series(rows, interval) do
    rows
    |> rows_to_data_by_paths()
    |> process_simple_series(interval)
  end

  @doc """
  Creates a series where chart values are computed as a sum of values for the last second.
  """
  @spec to_changes_per_second_series(rows_t(), interval_t(), accumulator :: map()) :: series_t()
  def to_changes_per_second_series(rows, interval, initial_accumulator) do
    rows
    |> rows_to_data_by_paths()
    |> process_changes_per_second_series(interval, initial_accumulator)
  end

  @doc """
  Creates an aggregate series with an increasing values (each value is a sum of all previous and current value).
  """
  @spec to_cumulative_series(rows_t(), interval_t(), accumulator :: map()) :: series_t()
  def to_cumulative_series(rows, interval, initial_accumulator) do
    rows
    |> rows_to_data_by_paths()
    |> process_cumulative_series(interval, initial_accumulator)
  end

  # converts rows from `measurements` table to list of tuples `{path_id, data}`, where data is a list of tuples contatining timestamps and values
  defp rows_to_data_by_paths(rows) do
    Enum.group_by(rows, fn [_time, path_id, _value] -> path_id end, fn [time, _path_id, value] ->
      {Decimal.to_float(time), value}
    end)
  end

  defp process_simple_series(data_by_paths, interval) do
    data_by_paths
    |> Enum.map(fn {path, data} ->
      processed_data =
        data
        |> process_path_data(fn time, values -> {time, Enum.max(values, fn -> 0 end)} end)
        |> Enum.into(%{})

      {{path, fill_with_nils(processed_data, interval)}, nil}
    end)
  end

  defp process_cumulative_series(data_by_paths, interval, initial_accumulators) do
    data_by_paths
    |> Enum.map(fn {path, data} ->
      processed_data =
        data
        |> process_path_data(fn time, values -> {time, Enum.sum(values)} end)
        |> Enum.into(%{})

      {data, accumulator} =
        fill_with_nils(processed_data, interval, initial_accumulators[path] || 0)

      {{path, data}, accumulator}
    end)
  end

  defp process_changes_per_second_series(data_by_paths, interval, initial_accumulators) do
    data_by_paths
    |> Enum.map(fn {path, data} ->
      initial_accumulator = Map.get(initial_accumulators, path, {0, []})

      {processed_data, accumulator} =
        calculate_changes_per_second_for_data(data, initial_accumulator)

      {{path, fill_with_nils(Map.new(processed_data), interval)}, accumulator}
    end)
  end

  # it basically traverses the list with data and for each measurement it replaces the value
  # with a sum calculated for a duration of one second till given timestamp
  #
  # accumulator consists of the last sum and measurements range of the last second before first timestamp in given data list,
  # it is needed in case when given data is an update data and the sum needs to be continuous  with previous data
  defp calculate_changes_per_second_for_data(data, initial_accumulator) do
    {init_sum, init_range} = initial_accumulator

    {sum, range, processed_data} =
      data
      |> Enum.reduce({init_sum, init_range, []}, fn {time, value}, {sum_so_far, range, acc} ->
        {to_stay, to_drop} =
          range
          |> Enum.split_while(fn {old_time, _value} ->
            time - old_time < 1.0
          end)

        to_subtract =
          to_drop
          |> Enum.map(&elem(&1, 1))
          |> Enum.sum()

        sum_so_far = sum_so_far - to_subtract + value

        {sum_so_far, [{time, value} | to_stay], [{time, sum_so_far} | acc]}
      end)

    {processed_data, {sum, range}}
  end

  # chunks measurements by the time (due to accuracy several measurements can have the same timestamp but only
  # one value can be displayed on the chart) then uses `reduce_time_values` function to reduce grouped values into a single one.
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

  # makes sure that border value read from user input has appropriate value to successfully match timestamps extracted from database
  defp apply_accuracy(time, accuracy),
    do: floor(time / (1000 * accuracy)) * accuracy

  # to put data to uPlot, it is necessary to fill every gap in data by nils
  defp fill_with_nils(path_data, interval),
    do: interval |> Enum.map(&path_data[&1])

  # if passed `initial_accumulator`, then value is equal to number of processed metrics plus `initial_accumulator` at every non-nil point
  defp fill_with_nils(path_data, interval, initial_accumulator) do
    interval
    |> Enum.map_reduce(initial_accumulator, fn timestamp, accumulator ->
      extract_with_measurements_counting(path_data, timestamp, accumulator)
    end)
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

  @doc """
  Unzips a list consisting of 3 element tuples into 3 separate lists.
  """
  @spec unzip3(list()) :: {list(), list(), list()}
  def unzip3(list),
    do: :lists.reverse(list) |> do_unzip3([], [], [])

  defp do_unzip3([{el1, el2, el3} | reversed_list], list1, list2, list3),
    do: do_unzip3(reversed_list, [el1 | list1], [el2 | list2], [el3 | list3])

  defp do_unzip3([], list1, list2, list3),
    do: {list1, list2, list3}
end
