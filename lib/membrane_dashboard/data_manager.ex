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

  @spec query(GenServer.server(), keyword()) :: :ok
  def query(manager, options) do
    GenServer.cast(manager, {:query, options, self()})
  end

  @spec loaded?(GenServer.server()) :: boolean()
  def loaded?(manager) do
    GenServer.call(manager, :loaded?)
  end

  @impl true
  def init(_opts) do
    {:ok, %{chart_contexts: %{}, alive_pipelines: [], last_query: nil}}
  end

  @impl true
  def handle_call(:loaded?, _from, state) do
    {:reply, state.chart_contexts != %{}, state}
  end

  @impl true
  def handle_cast({:query, options, respond_to}, state) do
    mode = Keyword.fetch!(options, :mode)
    time_from = Keyword.fetch!(options, :time_from)
    time_to = Keyword.fetch!(options, :time_to)

    send_data(respond_to, :query_start)

    {:ok, dagre} = Dagre.query(time_from, time_to)

    send_data(respond_to, :dagre, dagre)

    accuracy = Keyword.fetch!(options, :accuracy)
    metrics = Keyword.fetch!(options, :metrics)

    chart_contexts =
      Enum.reduce(metrics, [], fn metric, contexts ->
        new_context = %Context{
          time_from: time_from,
          time_to: time_to,
          metric: metric,
          accuracy: accuracy
        }

        mode =
          if Map.has_key?(state.chart_contexts, metric) do
            mode
          else
            :full
          end

        context =
          if mode == :update do
            state.chart_contexts
            |> Map.get(metric)
            |> merge_contexts(new_context)
          else
            new_context
          end

        {:ok, {chart, paths_mapping, df}} = query_module(mode).query(context)

        context = %Context{context | paths_mapping: paths_mapping, df: df}

        send_data(respond_to, :charts, {mode, metric, chart})

        [{metric, context} | contexts]
      end)

    alive_pipelines =
      Membrane.Dashboard.PipelineMarking.list_alive_pipelines(
        time_to
        |> DateTime.from_unix!(:millisecond)
        |> DateTime.to_naive()
      )

    send_data(respond_to, :alive_pipelines, alive_pipelines)

    send_data(respond_to, :query_end, {time_from, time_to})

    state = %{
      chart_contexts: Map.new(chart_contexts),
      alive_pipelines: alive_pipelines,
      last_query: DateTime.utc_now()
    }

    {:noreply, state}
  end

  defp query_module(:update), do: ChartsUpdate
  defp query_module(:full), do: ChartsFull

  defp merge_contexts(nil, new_context), do: new_context

  defp merge_contexts(old_context, new_context) do
    latest_time_to = old_context.time_to

    old_context
    |> struct(Map.take(new_context, [:time_from, :time_to, :metrics, :accuracy]))
    |> Map.replace!(:latest_time, latest_time_to)
  end

  defp send_data(respond_to, type) do
    send(respond_to, {:data_query, type})
  end

  defp send_data(respond_to, type, data) do
    send(respond_to, {:data_query, type, data})
  end
end
