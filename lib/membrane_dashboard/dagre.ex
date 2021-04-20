defmodule Membrane.Dashboard.Dagre do
  @moduledoc """
  Module responsible for fetching information from TimescaleDB exporter
  and formatting it to formats suitable for visualization.


  Records returned from TimescaleDB exporter are of format:
  +-------------+------+----+-----------+--------+
  | Parent path | From | To | Pad from  | Pad to |
  +-------------+------+----+-----------+--------+

  And this gets tricky from here:
  - parent path consists of pipeline/bin elements separated
    by "/" character - either 'From' or 'To' elements can be
    equal to "{Membrane.Bin, :itself}", that means that element
    is a bin, the last element from parent path to be precise

  - 'From' or 'To' mostly point to elements but again they can point
    to bins, this time "{Membrane.Bin, :itself}" name is not present,
    therefore it is needed to preprocess all elements to find all
    existing bins (append " bin" to element name and check if such bin
    exists in returned records, parent path is again important)
    e.g.

    Parent path:
      "/pipeline<...>/:rtp bin",
    From:
      "{Membrane.Bin, :itself}"

    'From' is actually an ":rtp bin" element.


    Parent path:
      "/pipeline<...>"
    From
      ":rtp"

    'From' is actually an ":rtp bin" element, we need
    to put it in "/pipeline<...>/:rtp bin" namespace
    and add " bin" sufix.


    For the dagre to be readable all bin elements with their
    respective pads should exists under it's own bin namespace so
    they can be easily grouped.

    Every element + their pad makes a node. Each exporter's records
    represents a single edge between elements.

    WARNING: Remember that dagre is built upon information of links
    that have been created in a specific time range, it does not
    take into account previously created links or that elements
    stopped working.
  """

  import Membrane.Dashboard.Helpers

  alias Membrane.Dashboard.Repo

  require Logger

  @spec query(non_neg_integer(), non_neg_integer()) :: {:ok, any()} | {:error, any()}
  def query(time_from, time_to) do
    result =
      """
      SELECT parent_path, l.from, l.to, pad_from, pad_to FROM links l WHERE time BETWEEN \
      '#{parse_time(time_from)}' AND '#{parse_time(time_to)}'
      """
      |> Repo.query()

    with {:ok, %Postgrex.Result{rows: links}} <- result,
         {:ok, dagre} <- links |> format_rows() |> __MODULE__.G6Marshaller.run() do
      %{nodes: nodes, edges: edges, combos: combos} = dagre
      [nodes, edges, combos] = [nodes, edges, combos] |> Enum.map(&MapSet.to_list/1)
      {:ok, %{nodes: nodes, edges: edges, combos: combos}}
    else
      {:error, _reason} -> {:error, "Failed to fetch links"}
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
end
