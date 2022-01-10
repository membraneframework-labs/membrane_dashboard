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

  alias Membrane.Dashboard.Charts
  alias Membrane.Dashboard.Charts.Context

  @doc """
  Queries database and marshals data to a format suitable for uPlot.

  Returns a separate chart data for each provided metric, list of
  chart paths (each chart has its own list of component paths) and a list
  of chart accumulators that can be reused by the chart in case of an real-time update (e.g. to cache some necessary information).
  """
  @spec query(Context.t()) ::
          Charts.chart_query_result_t()
  def query(%Context{time_from: time_from, time_to: time_to, metric: metric, accuracy: accuracy}) do
    case query_measurements(time_from, time_to, metric, accuracy) do
      {:ok, rows, paths_mapping} ->
        rows
        |> prepare_chart(time_from, time_to, metric, accuracy, paths_mapping)
        |> then(&{:ok, &1})

      _error ->
        chart = %{series: [], data: [[]]}
        {:ok, {chart, _paths_mapping = %{}, Explorer.DataFrame.from_map(%{})}}
    end
  end

  # prepares a single chart based on raw data from TimescaleDB
  defp prepare_chart(rows, time_from, time_to, metric, accuracy, paths_mapping) do
    df = Membrane.Dashboard.Charts.ChartDataFrame.from_rows(rows, time_from, time_to, accuracy)

    chart =
      cond do
        metric in ["caps", "event"] ->
          Membrane.Dashboard.Charts.ChartDataFrame.to_cumulative_chart(df, paths_mapping)

        metric in ["buffer", "bitrate"] ->
          Membrane.Dashboard.Charts.ChartDataFrame.to_changes_per_second_chart(
            df,
            paths_mapping,
            accuracy
          )

        true ->
          Membrane.Dashboard.Charts.ChartDataFrame.to_simple_chart(df, paths_mapping)
      end

    {chart, paths_mapping, df}
  end
end
