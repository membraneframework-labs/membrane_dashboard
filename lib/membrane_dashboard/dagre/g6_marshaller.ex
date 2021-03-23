defmodule Membrane.Dashboard.Dagre.G6Marshaller do
  use Membrane.Dashboard.Dagre.Marshaller

  @bin_itself "{Membrane.Bin, :itself}"

  @bin_node_style %{
    fill: "#ebb434",
  }

  @impl true
  def run(links) do
    bin_nodes = collect_bin_nodes(links)

    result = links
    |> Enum.map(fn link ->
      parents = link.parent_path |> String.split("/")

      last_parent = parents |> List.last()

      {from_is_bin, from_path} = element_path(link.parent_path, parents, link.from, bin_nodes)
      {to_is_bin, to_path} = element_path(link.parent_path, parents, link.to, bin_nodes)

      from = format_element(last_parent, link.from, link.pad_from, from_is_bin)
      to = format_element(last_parent, link.to, link.pad_to, to_is_bin)

      link |> Map.merge(%{
        from: from,
        from_node: generate_node(from_path, from),
        from_path: from_path,
        from_is_bin: from_is_bin,
        to: to,
        to_node: generate_node(to_path, to),
        to_path: to_path,
        to_is_bin: to_is_bin
      })
    end)
    |> Enum.reduce(%{nodes: MapSet.new(), edges: MapSet.new(), combos: MapSet.new()}, fn link, %{nodes: nodes, edges: edges, combos: combos} ->
      {from_combo, to_combo} = link_combos(link)


      %{
        nodes: nodes |> MapSet.put(%{
          id: link.from_node,
          label: link.from,
          comboId: from_combo.id,
          style: (if link.from_is_bin, do: @bin_node_style, else: %{}),
        }) |> MapSet.put(%{
          id: link.to_node,
          label: link.to,
          comboId: to_combo.id,
          style: (if link.to_is_bin, do: @bin_node_style, else: %{}),
        }),
        edges: edges |> MapSet.put(%{
          source: link.from_node,
          target: link.to_node
        }),
        combos: combos |> MapSet.put(from_combo) |> MapSet.put(to_combo)
      }
    end)

    {:ok, result}
  end

  defp collect_bin_nodes(links) do
    links
    |> Enum.map(& &1.parent_path)
    |> Enum.filter(& String.ends_with?(&1, " bin"))
    |> MapSet.new()
  end

  defp link_combos(link) do
    from_combo = combo(link.from_path)
    to_combo = combo(link.to_path)

    {from_combo, to_combo}
  end

  defp combo(path) do
    id = path |> Enum.join() |> hash_string()
    [label | parents] = path |> Enum.reverse()
    parent_id = if length(parents) == 0 do
      nil
    else
      parents |> Enum.reverse() |> Enum.join() |> hash_string()
    end

    %{
      id: id,
      label: label,
      parentId: parent_id
    }
  end


  defp format_element(last_parent, @bin_itself, pad, _is_bin), do: String.replace_suffix(last_parent, " bin", "") <> "\n" <> pad
  defp format_element(_last_parent, element, pad, true), do: element <> "\n" <> pad
  defp format_element(_last_parent, element, _pad, false), do: element

  defp generate_node(path, element) do
    "#{path |> Enum.join()}#{element}" |> hash_string()
  end

  defp hash_string(to_hash), do: to_hash |> :erlang.md5() |> Base.encode16()

  # element_path is responsible for retrieving element path
  # it gets tricky when element itself is a bin
  defp element_path(_parent_path, parents, @bin_itself, _bin_nodes) do
    {true, parents}
  end

  defp element_path(parent_path, parents, element, bin_nodes) do
    element_bin = "#{element} bin"
    bin_path = "#{parent_path}/#{element_bin}"

    if MapSet.member?(bin_nodes, bin_path) do
      {true, parents ++ [element_bin]}
    else
      {false, parents}
    end
  end
end
