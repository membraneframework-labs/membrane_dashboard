defmodule Membrane.Dashboard.Charts.ChartDataFrame do
  @moduledoc """
  Module responsible for manipulating a data frame carrying chart's internal data.

  It is responsible for parsing raw rows returned from TimescaleDB database
  and putting it into Explorer's data frame.

  Given a loaded data frame one can extract the proper chart of available types:
  * `simple` - simple chart that just plots series values without changing them
  * `cumulative` - chart with series containing cumulative sum for each following value
  * `changes_per_second` - chart with a rolling sum of values spanned for one second
  """

  alias Membrane.Dashboard.Charts.Helpers
  alias Explorer.DataFrame
  alias Explorer.Series

  @type chart_t :: %{
          series: [%{label: String.t()}],
          data: [[float()]]
        }

  @spec from_rows([any()], non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          DataFrame.t()
  def from_rows(rows, time_from, time_to, accuracy) do
    timestamps = Helpers.timeline_timestamps(time_from, time_to, accuracy)
    interval = {time_from, time_to, accuracy}

    case rows do
      [] ->
        DataFrame.from_map(%{"timestamps" => timestamps})

      rows ->
        rows
        |> process_rows(interval)
        # dataframe columns can't be numbers so keep path ids
        |> Map.new(fn {path_id, data} -> {inspect(path_id), data} end)
        |> DataFrame.from_map()
        |> DataFrame.mutate(%{"timestamps" => timestamps})
    end
  end

  @spec to_simple_chart(DataFrame.t(), map()) :: chart_t()
  def to_simple_chart(df, paths_mapping) do
    to_chart(df, paths_mapping, &Series.to_list/1)
  end

  @spec to_changes_per_second_chart(DataFrame.t(), map(), non_neg_integer()) :: chart_t()
  def to_changes_per_second_chart(df, paths_mapping, accuracy) do
    rolling_sum_step = div(1000, accuracy)

    to_chart(df, paths_mapping, fn series ->
      series
      # replace nils with zeroes as this breaks the rolling_sum calculations
      |> Series.transform(&if(is_nil(&1), do: 0, else: &1))
      |> Series.rolling_sum(rolling_sum_step, nil, false)
      |> Series.to_list()
    end)
  end

  @spec to_cumulative_chart(DataFrame.t(), map()) :: chart_t()
  def to_cumulative_chart(df, paths_mapping) do
    to_chart(df, paths_mapping, fn series ->
      series
      |> Series.cum_sum()
      |> Series.to_list()
    end)
  end

  defp to_chart(df, path_mappings, series_reducer) do
    series = DataFrame.to_map(df, false)

    {timestamps, series} = Map.pop!(series, :timestamps)

    {paths, data} =
      series
      |> Enum.map(fn {path_id, series} ->
        {path_id |> Atom.to_string() |> String.to_integer(), series_reducer.(series)}
      end)
      |> Enum.sort_by(fn {path_id, _values} -> path_id end)
      |> Enum.unzip()

    labels = [%{label: "time"} | Enum.map(paths, &%{label: Map.fetch!(path_mappings, &1)})]

    %{series: labels, data: [Series.to_list(timestamps) | data]}
  end

  @doc """
  Merges two data frames.

  During merging it auto completes series that are not present in either data frame
  to the opposite data frame filling them with nils.

  Additionally the merging operating looks for stale series (present in first data frame but not
  in the second one while having all values set to nil) and deletes them.

  The `back_shift` parameter is used to overwrite `df1`'s last measurements by the `df2`'s
  in case `df1` has incomplete measurements which may happen when the necessary data has not yet been saved to database.
  """
  @spec merge(DataFrame.t(), DataFrame.t(), non_neg_integer()) :: DataFrame.t()
  def merge(df1, df2, back_shift) do
    series1 = df1 |> DataFrame.names() |> MapSet.new()
    series2 = df2 |> DataFrame.names() |> MapSet.new()

    old_series = MapSet.difference(series1, series2)
    new_series = MapSet.difference(series2, series1)

    series_to_drop =
      old_series
      |> Enum.filter(fn series ->
        df1
        |> DataFrame.pull(series)
        # don't trust the dialyzer, it can return nil when all values in a series a nils
        |> Series.sum() == nil
      end)
      |> MapSet.new()

    old_series = MapSet.difference(old_series, series_to_drop)

    # we can't simply test whether the old values are stale or not
    # the only way is to check whether in the last span they have been added at least once, if
    # not then they should get removed from there

    # we need to create missing data for the old series (adding old series to df2)
    # we need to create missing data for new series (adding new series to df1)
    # and finally merge both of them together

    {old_series_n, _} = DataFrame.shape(df1)
    {new_series_n, _} = DataFrame.shape(df2)

    [old_series_nils, new_series_nils] =
      [old_series_n - new_series_n, new_series_n]
      |> Enum.map(fn n ->
        1..n
        |> Enum.map(& &1)
        |> Series.from_list()
        |> Series.transform(fn _val -> nil end)
      end)

    df1 =
      df1
      |> DataFrame.select(MapSet.to_list(series_to_drop), :drop)
      # we need to drop leading values from rows
      |> DataFrame.slice(new_series_n, old_series_n - new_series_n - back_shift)
      |> DataFrame.mutate(new_series |> Map.new(&{&1, old_series_nils}))

    df2 = DataFrame.mutate(df2, old_series |> Map.new(&{&1, new_series_nils}))

    DataFrame.concat_rows(df1, df2)
  end

  defp process_rows(rows, interval) do
    rows
    |> rows_to_data_by_paths()
    |> Enum.map(fn {path, data} ->
      data =
        data
        |> process_path_data(fn time, values -> {time, Enum.sum(values)} end)
        |> fill_series_gaps(interval)

      {path, data}
    end)
  end

  # converts rows from `measurements` table to list of tuples `{path_id, data}`, where data is a list of tuples contatining timestamps and values
  defp rows_to_data_by_paths(rows) do
    Enum.group_by(rows, fn [_time, path_id, _value] -> path_id end, fn [time, _path_id, value] ->
      {Decimal.to_float(time), value}
    end)
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

  # given an interval fills the gaps between data's timestamps with nils
  @eps 0.001
  defp fill_series_gaps(data, interval) do
    {from, to, accuracy} = interval
    accuracy_in_seconds = Helpers.to_seconds(accuracy)

    size = Helpers.timeline_interval_size(from, to, accuracy)

    from = Helpers.apply_accuracy(from, accuracy_in_seconds)

    from
    |> Stream.iterate(&(&1 + accuracy_in_seconds))
    |> Stream.take(size)
    |> Enum.reduce({[], data}, fn
      _time_point, {filled_data, []} ->
        {[nil | filled_data], []}

      time_point, {filled_data, [{data_time, value} | data] = all_data} ->
        diff = data_time - time_point

        cond do
          # case where data's time is greater so we must fill the current point with nil
          diff > @eps ->
            {[nil | filled_data], all_data}

          # case where data's time equals the time_point so put the values here
          diff < @eps and diff >= 0.0 ->
            {[value | filled_data], data}

          # case where time_point is greater than the data's time, should not happen (or happen rarely)
          true ->
            {[nil | filled_data],
             Enum.drop_while(data, fn {drop_time, _value} -> drop_time - time_point < @eps end)}
        end
    end)
    |> then(fn {filled_data, _data} ->
      Enum.reverse(filled_data)
    end)
  end
end
