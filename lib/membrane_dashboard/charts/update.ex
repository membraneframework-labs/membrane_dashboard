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
  def query(%Context{time_to: time_to, metric: metric, accuracy: accuracy, df: old_df} = context) do
    %Context{
      paths_mapping: old_paths_mapping,
      latest_time: last_time_to
    } = context

    # query 2 seconds back to compensate for potentially data that has not yet been inserted
    back_shift = floor(1_000 / accuracy * 2)

    update_from = last_time_to - accuracy * back_shift

    case query_measurements(update_from, time_to, metric, accuracy) do
      {:ok, rows, new_paths_mapping} ->
        paths_mapping = Map.merge(old_paths_mapping, new_paths_mapping)

        new_df =
          Membrane.Dashboard.Charts.ChartDataFrame.from_rows(rows, update_from, time_to, accuracy)

        # back_shift + 1 because we don't want to repeat the last timestamp twice
        df = Membrane.Dashboard.Charts.ChartDataFrame.merge(old_df, new_df, back_shift + 1)

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

        {:ok, {chart, paths_mapping, df}}

      :error ->
        {:error, "Cannot fetch update data for charts"}
    end
  end
end
