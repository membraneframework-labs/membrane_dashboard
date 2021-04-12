defmodule Membrane.Dashboard.Charts do
  import Membrane.Dashboard.Helpers

  alias Membrane.Dashboard.Repo

  @accuracy 0.01

  def query_charts(time_from, time_to) do
    result =
      """
      SELECT floor(extract(epoch from "time")/#{@accuracy})*#{@accuracy} AS "time",
      path,
      value AS "value"
      FROM measurements m JOIN element_paths ep on m.element_path_id = ep.id
      WHERE
      "time" BETWEEN '#{parse_time(time_from)}' AND '#{parse_time(time_to)}' and method = 'store'
      GROUP BY 1, path, value
      ORDER BY 1
      """
      |> Repo.query()

    {:ok, %Postgrex.Result{rows: rows}} = result

    interval = create_interval(time_from, time_to)
    data_by_pipelines = to_series(rows, interval)

    {:ok, %{series: extract_opt_series(data_by_pipelines), data: extract_data(interval, data_by_pipelines)}}
  end

  defp create_interval(from_millis, to_millis) do
    {from, to} = {apply_accuracy(from_millis), apply_accuracy(to_millis)}
    size = floor((to - from) / @accuracy)

    for x <- 0..size, do: from + x * @accuracy
  end

  defp apply_accuracy(time) do
    floor(time / (1000 * @accuracy)) * @accuracy
  end

  defp to_series(rows, interval) do
    rows =
      rows
      |> Enum.group_by(fn [_time, name, _size] -> name end, fn [time, _name, size] -> [time, size] end)
      |> Enum.map(fn {name, group} -> {name, Enum.group_by(group, fn [time, _size] -> time end, fn [_time, size] -> size end)} end)
      |> Enum.map(fn {name, name_group} -> {name, Enum.map(name_group, fn {time, time_group} -> {time, Enum.max(time_group)} end)} end)
      |> Enum.map(fn {name, name_group} -> {name, Enum.into(name_group, %{})} end)

    Enum.map(rows, fn {name, group_data} -> {name, fill(group_data, interval)} end)
  end

  defp fill(data, interval) do
    interval |> Enum.map(&(data[&1]))
  end

  defp extract_opt_series(data_by_pipelines) do
    series =
      data_by_pipelines
      |> Enum.map(fn {pipeline_name, _data} -> [{:label, pipeline_name}] end)
      |> Enum.map(fn series -> Enum.into(series, %{}) end)

    [%{label: "time"} | series]
  end

  defp extract_data(interval, data_by_pipelines) do
    data =
      data_by_pipelines
      |> Enum.map(fn {_pipeline_name, data} -> data end)

    [interval | data]
  end

  defp date_from_unix(interval) do
    Enum.map(interval, fn time -> DateTime.to_string(DateTime.from_unix!(floor(1000*time), :millisecond)) end)
  end
end
