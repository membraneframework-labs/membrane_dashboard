defmodule Membrane.Dashboard.Charts.Helpers do
  @moduledoc """
  Module has methods useful for Membrane.Dashboard.Charts.Full and Membrane.Dashboard.Charts.Update.
  """

  import Membrane.Dashboard.Helpers

  # returns query to select all measurements from database for given method, accuracy and time range (last two in milliseconds)
  @spec create_sql_query(non_neg_integer(), non_neg_integer(), non_neg_integer(), String.t()) ::
          String.t()
  def create_sql_query(accuracy, time_from, time_to, method) do
    accuracy_in_seconds = to_seconds(accuracy)

    """
      SELECT floor(extract(epoch from "time")/#{accuracy_in_seconds})*#{accuracy_in_seconds} AS time,
      path,
      value
      FROM measurements m JOIN element_paths ep on m.element_path_id = ep.id
      WHERE
      time BETWEEN '#{parse_time(time_from)}' AND '#{parse_time(time_to)}' and method = '#{method}'
      GROUP BY time, path, value
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
  Gets rows of TimescaleDB's measurements table and `interval` as list of timestamps.

  Returns list of tuples `{path, data}`, where `path` is pipeline element path and data is a list with
  values (one value for every timestamp in `interval`).
  """
  @spec to_series([[term()] | binary()] | nil, [float()]) :: [{String.t(), [non_neg_integer()]}]
  def to_series(rows, interval) do
    rows
    |> Enum.group_by(fn [_time, path, _size] -> path end, fn [time, _path, size] ->
      {time, size}
    end)
    |> Enum.map(fn {path, data} ->
      data =
        data
        |> group_by_time()
        |> get_max_value_for_every_timestamp()
        |> Enum.into(%{})
        |> fill_with_nils(interval)

      {path, data}
    end)
  end

  # makes sure that border value read from user input has appropriate value to successfully match timestamps extracted from database
  defp apply_accuracy(time, accuracy),
    do: floor(time / (1000 * accuracy)) * accuracy

  # receives list of all tuples {time, buffer_size} for one pipeline path
  # groups buffer sizes by timestamps (there can be more than one buffer size per timestamp depending on `accuracy`)
  defp group_by_time(path_data),
    do: path_data |> Enum.group_by(fn {time, _size} -> time end, fn {_time, size} -> size end)

  # extracts one maximal buffer size for every timestamp in passed pipeline path data
  defp get_max_value_for_every_timestamp(path_data),
    do: path_data |> Enum.map(fn {time, time_group} -> {time, Enum.max(time_group)} end)

  # to put data to uPlot, it is necessary to fill every gap in data by nils
  defp fill_with_nils(path_data, interval),
    do: interval |> Enum.map(&path_data[&1])
end
