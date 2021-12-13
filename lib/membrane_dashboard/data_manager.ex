defmodule Membrane.Dashboard.DataManager do
  @moduledoc """
  Module responsible for querying and caching data necessary for displaying on dashboard
  """

  use GenServer

  alias Membrane.Dashboard.Charts.Context
  alias Membrane.Dashboard.Charts.Full, as: ChartsFull
  alias Membrane.Dashboard.Charts.Update, as: ChartsUpdate
  alias Membrane.Dashboard.Dagre

  @spec start_link() :: GenServer.on_start()
  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  @spec start() :: GenServer.on_start()
  def start() do
    GenServer.start(__MODULE__, [])
  end

  @spec query(GenServer.t(), keyword()) :: :ok
  def query(manager, options) do
    GenServer.cast(manager, {:query, options, self()})
  end

  @impl true
  def init(_opts) do
    {:ok, %{charts_context: nil, alive_pipelines: [], last_query: nil}}
  end

  @impl true
  def handle_cast({:query, options, respond_to}, state) do
    mode = Keyword.fetch!(options, :mode)
    time_from = Keyword.fetch!(options, :time_from)
    time_to = Keyword.fetch!(options, :time_to)

    send_data(respond_to, :query_start)

    {:ok, dagre} = Dagre.query(time_from, time_to)

    send_data(respond_to, :dagre, dagre)

    metrics =
      Keyword.get_lazy(
        options,
        :metrics,
        fn -> state.charts_context[:metrics] || raise("missing 'metrics' parameter") end
      )

    accuracy =
      Keyword.get_lazy(
        options,
        :accuracy,
        fn -> state.charts_context[:accuracy] || raise("missing 'accuracy' parameter") end
      )

    new_context = %Context{
      time_from: time_from,
      time_to: time_to,
      metrics: metrics,
      accuracy: accuracy
    }

    context =
      if mode == :update do
        merge_contexts(state.charts_context, new_context)
      else
        new_context
      end

    {:ok, {charts, paths, accumulators}} = query_module(mode).query(context)

    context = %Context{context | data: charts, paths: paths, accumulators: accumulators}

    send_data(respond_to, :charts, {mode, charts, elements_tree(paths)})

    alive_pipelines =
      Membrane.Dashboard.PipelineMarking.list_alive_pipelines(
        time_to
        |> DateTime.from_unix!(:millisecond)
        |> DateTime.to_naive()
      )

    send_data(respond_to, :alive_pipelines, alive_pipelines)

    send_data(respond_to, :query_end, {time_from, time_to})

    {:noreply,
     %{charts_context: context, alive_pipelines: alive_pipelines, last_query: DateTime.utc_now()}}
  end

  defp query_module(:update), do: ChartsUpdate
  defp query_module(:full), do: ChartsFull

  defp merge_contexts(nil, new_context), do: new_context

  defp merge_contexts(old_context, new_context) do
    struct(old_context, Map.take(new_context, [:time_from, :time_to, :metrics, :accuracy]))
  end

  defp send_data(respond_to, type) do
    send(respond_to, {:data_query, type})
  end

  defp send_data(respond_to, type, data) do
    send(respond_to, {:data_query, type, data})
  end

  # Groups paths so that they create a tree of elements (nested maps, each key pointing to its children).
  #
  # By starting with a root element (a pipeline) we can go down the tree
  # to checks for its children (either bins or elements) by eventually reaching
  # the leafs which in this case should be simple elements.
  # Leafs can be recognized as they point to empty maps.
  defp elements_tree(paths) do
    paths
    |> List.flatten()
    |> MapSet.new()
    |> MapSet.to_list()
    |> Enum.map(&(String.split(&1, "/") |> Enum.reverse() |> tl() |> Enum.reverse()))
    |> do_group()
  end

  defp do_group([]), do: %{}

  defp do_group(list) when is_list(list) do
    list
    |> Enum.group_by(&hd/1, &tl/1)
    |> Enum.map(fn {key, value} ->
      value =
        value
        |> Enum.reject(&(&1 == []))
        |> do_group()

      {key, value}
    end)
    |> Map.new()
  end
end
