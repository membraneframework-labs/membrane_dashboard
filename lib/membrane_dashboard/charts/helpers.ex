defmodule Membrane.Dashboard.Charts.Helpers do
  @moduledoc """
  Module has functions useful for Membrane.Dashboard.Charts.Full and Membrane.Dashboard.Charts.Update.
  """

  import Membrane.Dashboard.Helpers
  import Ecto.Query, only: [from: 2]

  alias Membrane.Dashboard.Repo
  alias Membrane.Dashboard.Charts

  require Logger

  @type rows_t :: [[term()]]
  @type interval_t ::
          {time_from :: non_neg_integer(), time_to :: non_neg_integer(),
           accuracy :: non_neg_integer()}
  @type series_t :: [
          {{path_id :: non_neg_integer(), data :: list(integer())}, accumulator :: any()}
        ]

  @doc """
  Queries all measurements for given time range, metric and accuracy and returns them together
  with mapping of its component path ids to the path strings.
  """
  @spec query_measurements(non_neg_integer(), non_neg_integer(), String.t(), non_neg_integer()) ::
          {:ok, rows_t(), Charts.chart_paths_mapping_t()} | :error
  def query_measurements(time_from, time_to, metric, accuracy) do
    with {:ok, %Postgrex.Result{rows: measurements_rows}} <-
           Repo.query(measurements_query(time_from, time_to, metric, accuracy)),
         component_path_rows <- Repo.all(component_paths_query(measurements_rows)) do
      paths_mapping = Map.new(component_path_rows)

      {:ok, measurements_rows, paths_mapping}
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
  @spec timeline_timestamps(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: [float()]
  def timeline_timestamps(from, to, accuracy) do
    accuracy_in_seconds = to_seconds(accuracy)

    size = timeline_interval_size(from, to, accuracy)
    from = apply_accuracy(from, accuracy_in_seconds)

    for x <- 1..size, do: from + x * accuracy_in_seconds
  end

  @doc """
  Applies accuracy to a time represented in a number of milliseconds to match format returned from database.
  """
  @spec apply_accuracy(non_neg_integer(), float()) :: float()
  def apply_accuracy(time, accuracy),
    do: floor(time / (1000 * accuracy)) * accuracy
end
