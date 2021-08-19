defmodule Membrane.Dashboard.Charts.Full do
  @moduledoc """
  Module responsible for preparing data for uPlot charts when they are being entirely reloaded.

  Every chart visualizes one particular metric of pipelines. Chart data returned
  by query is a list of maps (one for every chart) which consist of:
  - series - list of maps with labels. Used as legend in uPlot;
  - data - list of lists. Represents points on the chart. First list contains timestamps in UNIX time (x axis ticks).
    Each following list consists of metric values, each value corresponds to a timestamp from the first list.
  """

  import Membrane.Dashboard.Charts.Helpers

  alias Membrane.Dashboard.Repo
  alias Membrane.Dashboard.Charts

  @doc """
  Queries database and marshals data to a format suitable for uPlot.

  Returns a separate chart data for each provided metric, list of
  chart paths (each chart has its own list of component paths) and a list
  of chart accumulators that can be reused by the chart in case of an real-time update (e.g. to cache some necessary information).
  """
  @spec query([String.t()], non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          Charts.chart_query_result_t()
  def query(metrics, time_from, time_to, accuracy) do
    case create_sql_query(accuracy, time_from, time_to) |> Repo.query() do
      {:ok, %Postgrex.Result{rows: rows}} ->
        rows_by_metrics = group_rows_by_metrics(rows)

        metrics
        |> Enum.map(
          &prepare_chart(&1, Map.get(rows_by_metrics, &1, []), time_from, time_to, accuracy)
        )
        |> unzip3()
        |> then(&{:ok, &1})

      _error ->
        metrics
        |> Enum.map(fn _metric -> {%{series: [], data: [[]]}, [], []} end)
        |> unzip3()
    end
  end

  # prepares a single chart based on raw data from TimescaleDB
  defp prepare_chart(metric, rows, time_from, time_to, accuracy) do
    interval = timeline_interval(time_from, time_to, accuracy)

    {path_to_data, accumulators} =
      cond do
        metric in ["caps", "event"] -> to_cumulative_series(rows, interval, %{})
        metric in ["buffer", "bitrate"] -> to_changes_per_second_series(rows, interval, %{})
        true -> to_simple_series(rows, interval)
      end
      |> Enum.unzip()

    {paths, data} = Enum.unzip(path_to_data)

    chart_data = %{
      series: series_from_paths(paths),
      data: [interval | data]
    }

    mapped_accumulators =
      paths
      |> Enum.zip(accumulators)
      |> Map.new()

    {chart_data, paths, mapped_accumulators}
  end

  defp series_from_paths(paths) do
    [%{label: "time"} | Enum.map(paths, &%{label: &1})]
  end
end
