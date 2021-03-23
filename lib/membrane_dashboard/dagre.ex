defmodule Membrane.Dashboard.Dagre do
  @moduledoc """
  Module responsible for fetching information from TimescaleDB exporter
  and formatting it to formats suitable for visualization.
  """

  alias Membrane.Dashboard.Repo

  require Logger

  @type time_interval_t :: non_neg_integer()

  @beginning_of_time ~U[1970-01-01 00:00:00Z]

  @interval_pattern Regex.compile!("([0-9]+)(s|m|h|d|M|y)")

  @spec query_dagre(time_interval_t(), time_interval_t()) :: {:ok, any()} | {:error, any()}
  def query_dagre(time_from, time_to) do
    result =
      "SELECT parent_path, l.from, l.to, pad_from, pad_to FROM links l WHERE time BETWEEN '#{
        parse_time(time_from)
      }' AND '#{parse_time(time_to)}'"
      |> Repo.query()

    with {:ok, %Postgrex.Result{rows: links}} <- result,
         {:ok, dagre} <- links |> format_rows() |> __MODULE__.G6Marshaller.run() do
      %{
        nodes: nodes,
        edges: edges,
        combos: combos
      } = dagre

      [nodes, edges, combos] = [nodes, edges, combos] |> Enum.map(&MapSet.to_list/1)
      {:ok, %{nodes: nodes, edges: edges, combos: combos}}
    else
      {:error, reason} ->
        {:error, "Failed to fetch links"}
    end
  end

  defp format_rows(rows) do
    rows
    |> Enum.map(fn [parent_path, from, to, pad_from, pad_to] ->
      %{
        parent_path: parent_path,
        from: from,
        to: to,
        pad_from: pad_from,
        pad_to: pad_to
      }
    end)
  end

  defp parse_time(time) when is_number(time) do
    @beginning_of_time |> DateTime.add(time, :millisecond)
  end

  defp parse_time("now") do
    DateTime.utc_now()
  end

  defp parse_time("now-" <> interval) do
    {time, unit} = parse_interval(interval)

    DateTime.utc_now() |> DateTime.add(time, unit)
  end

  defp parse_interval(interval) do
    [_, time, unit] = Regex.run(@interval_pattern, interval)

    {unit, multiplier} =
      case unit do
        "s" -> {:second, 1}
        "m" -> {:minute, 1}
        "h" -> {:minute, 60}
        "d" -> {:minute, 60 * 24}
        "M" -> {:minute, 60 * 24 * 30}
        "y" -> {:minute, 60 * 24 * 365}
      end

    {String.to_integer(time) * multiplier, unit}
  end
end
