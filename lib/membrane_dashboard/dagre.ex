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
    import Ecto.Query

    query_links = fn elements ->
      from(l in "links",
        where: fragment("concat(?, '/', ?)", l.parent_path, l.from) in ^elements or fragment("concat(?, '/', ?)", l.parent_path, l.to) in ^elements,
        select: [l.parent_path, l.from, l.to, l.pad_from, l.pad_to])
      |> Repo.all()
    end

   with {:ok, all_alive_elements} <- alive_element_paths(time_from, time_to),
      {:ok, dead_elements} <- element_paths_in_time_range(time_from, time_to, true),
      {:ok, new_elements} <- element_paths_in_time_range(time_from, time_to, false),
      existing_elements <- MapSet.difference(all_alive_elements, new_elements),
      elements_to_query <- MapSet.union(all_alive_elements, dead_elements),
      links <- elements_to_query |> Enum.map(& String.replace(&1, "\\", ""))  |> query_links.(),
         {:ok, dagre} <- links |> format_rows() |> __MODULE__.G6Marshaller.run([dead: dead_elements, new: new_elements, existing: existing_elements]) do
      %{nodes: nodes, edges: edges, combos: combos} = dagre
      [nodes, edges, combos] =
        [nodes, edges, combos]
        |> Enum.map(fn
          %MapSet{} = set -> MapSet.to_list(set)
          list -> list
        end)
      {:ok, %{nodes: nodes, edges: edges, combos: combos}}
    else
      {:error, reason} ->
        {:error, reason}
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

  defp alive_element_paths(time_from, time_to) do
    # Some explanation...
    #
    # We need to fetch all elements that either have already existed in given time range or have just been created.
    # There can be 2 different cases:
    # - element has never died, just select it
    # - element has died but it happened after `time_to` timestamp
    #
    # If the data is not corrupted (all termination events have been registered successfully) then for given path we can have
    # 2 entries which one indicates element initialization and the other one element termination. If 2 entries exits then
    # just check if the latter entry happened after `time_to`.
    result =  """
    SELECT path as total FROM elements
    GROUP BY path
    HAVING MIN(time) < '#{parse_time(time_to)}' AND (
      CASE
        WHEN COUNT(*) = 2 THEN MAX(time) > '#{parse_time(time_to)}'
        ELSE true
       END
    );
    """ |> Repo.query()

    with {:ok, %Postgrex.Result{rows: elements}} <- result do
      {:ok, format_element_paths(elements)}
    else
      {:error, reason} ->
        Logger.error(inspect(reason))
        {:error, "Failed to fetch elements"}
    end
  end

  def element_paths_in_time_range(time_from, time_to, terminated?) do
    result = "SELECT path FROM elements where terminated = #{terminated?} AND time BETWEEN '#{parse_time(time_from)}' and '#{parse_time(time_to)}'" |> Repo.query()

    with {:ok, %Postgrex.Result{rows: elements}} <- result do
      {:ok, format_element_paths(elements)}
    else
      {:error, reason} ->
        Logger.error(inspect(reason))
        {:error, "Failed to fetch elements"}
    end
  end

  defp format_element_paths(elements) do
    elements
    |> Enum.map(fn [path] -> String.replace(path, "\\", "") end)
    |> MapSet.new()
  end
end
