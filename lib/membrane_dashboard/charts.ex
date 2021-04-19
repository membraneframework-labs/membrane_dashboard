defmodule Membrane.Dashboard.Charts do
  @moduledoc """
  Module responsible for preparing data for uPlot charts.

  Every chart visualizes sizes of buffers found when processing one particular method in pipelines. Data is a map from
  method name to chart data. That chart data consists of:
  - series - list of maps with labels. Used as legend in uPlot;
  - data - list of lists. Represents points on the chart. First list contains timestamps in UNIX time (x axis ticks).
    Every next list have information about one pipeline path. Such list have max buffer size for every timestamp from
    first list.
  """

  import Membrane.Dashboard.Helpers

  alias Membrane.Dashboard.Repo

  @accuracy 0.01

  @type chart_data_t :: %{
    series: list(%{label: String.t()}),
    data: list(list(integer()))
  }

  @doc """
  Queries database to get data appropriate for uPlot. Returns all data for all given methods and time interval
  between 'time_from' and 'time_to'.
  """
  @spec query(list(String.t()), non_neg_integer(), non_neg_integer()) :: {:ok, list(chart_data_t())}
  def query(methods, time_from, time_to) do
    charts_data =
      methods
      |> Enum.map(fn method -> one_chart_query(method, time_from, time_to) end)

    {:ok, charts_data}
  end

  # returns data for one method in the given time interval
  @spec one_chart_query(list(String.t()), non_neg_integer(), non_neg_integer()) :: chart_data_t()
  defp one_chart_query(method, time_from, time_to) do
    result =
      """
      SELECT floor(extract(epoch from "time")/#{@accuracy})*#{@accuracy} AS time,
      path,
      value AS "value"
      FROM measurements m JOIN element_paths ep on m.element_path_id = ep.id
      WHERE
      time BETWEEN '#{parse_time(time_from)}' AND '#{parse_time(time_to)}' and method = '#{method}'
      GROUP BY time, path, value
      ORDER BY time
      """
      |> Repo.query()

    {:ok, %Postgrex.Result{rows: rows}} = result

    interval = create_interval(time_from, time_to)
    data_by_paths = to_series(rows, interval)
    chart_data = %{
      series: extract_opt_series(data_by_paths),
      data: extract_data(interval, data_by_paths)
    }

    chart_data
  end

  # time in uPlot have to be discrete, so every event from database will land in one specific timestamp from returned interval
  # returns list of timestamps between 'from' and 'to' with difference between two neighboring values equal to '@accuracy' seconds
  defp create_interval(from, to) do
    [from, to] = [apply_accuracy(from), apply_accuracy(to)]
    size = floor((to - from) / @accuracy)

    for x <- 0..size, do: from + x * @accuracy
  end

  # makes sure that border value read from user input has appropriate value to successfully match timestamps extracteed from database
  defp apply_accuracy(time) do
    floor(time / (1000 * @accuracy)) * @accuracy
  end

  # returns list of tuples, where every tuple contains information about one pipeline path
  # tuples are in format: {path, data}, where data is a list with values for every timestamp in 'interval'
  defp to_series(rows, interval) do
    rows
    |> Enum.group_by(fn [_time, path, _size] -> path end, fn [time, _path, size] -> {time, size} end)
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

  # receives list of all tuples {time, buffer_size} for one pipeline path
  # groups buffer sizes by timestamps (there can be more than one buffer size per timestamp depending on '@accuracy')
  defp group_by_time(path_data), do:
    path_data |> Enum.group_by(fn {time, _size} -> time end, fn {_time, size} -> size end)

  # extracts one maximal buffer size for every timestamp in passed pipeline path data
  defp get_max_value_for_every_timestamp(path_data), do:
    path_data |> Enum.map(fn {time, time_group} -> {time, Enum.max(time_group)} end)

  # to put data to uPlot, it is necessary to fill every gap in data by nils
  defp fill_with_nils(path_data, interval), do:
    interval |> Enum.map(&(path_data[&1]))

  # returns list of maps serializable to Series objects in uPlot
  # that list will be used to create legend for uPlot
  # example list: [%{label: "time"}, %{label: "pipeline@<0.584.0>/:realtimer_video/:input:"}, %{label: "pipeline@..."}]
  defp extract_opt_series(data_by_paths) do
    series =
      data_by_paths
      |> Enum.map(fn {path, _data} -> [{:label, path}] end)
      |> Enum.map(fn series -> Enum.into(series, %{}) end)

    [%{label: "time"} | series]
  end

  # returns data for uPlot in format: [x axis labels, series 1, series 2, ...]
  defp extract_data(interval, data_by_paths) do
    data =
      data_by_paths
      |> Enum.map(fn {_path, data} -> data end)

    [interval | data]
  end
end
