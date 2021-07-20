defmodule Membrane.DashboardWeb.DashboardLive do
  @moduledoc """
  Live view controller for Membrane's dashboard.
  """
  use Membrane.DashboardWeb, :live_view

  alias Membrane.Dashboard.{Dagre, Helpers}
  alias Membrane.Dashboard.Charts.Full, as: ChartsFull
  alias Membrane.Dashboard.Charts.Update, as: ChartsUpdate
  alias Membrane.DashboardWeb.Router.Helpers, as: Routes

  require Logger

  @metrics ["caps", "event", "store", "take_and_demand", "buffer", "queue_len", "bitrate"]

  @initial_time_offset 60
  @initial_accuracy 100

  @update_time 5

  # initially:
  # - time range is the last `@initial_time_offset` seconds
  # - live update is enabled - now updates `@update_time` seconds after last sending data to uPlot
  # - charts are created based on current metrics in database
  # - `paths` and `data` needed for live update have lists of empty lists
  @impl true
  def mount(_params, _session, socket) do
    empty_lists = for _metric <- 1..length(@metrics), do: []

    if connected?(socket) do
      send(self(), {:charts_init, @metrics})
    end

    socket =
      socket
      |> assign(
        # data query params
        time_from: now(-@initial_time_offset),
        time_to: now(),
        accuracy: @initial_accuracy,
        update_range: @initial_time_offset,

        # cached query data
        metrics: @metrics,
        paths: empty_lists,
        data: empty_lists,

        # real-time update timer
        update_ref: nil,
        update: false,

        # data query task ref
        query_task_ref: nil,

        # UI related
        data_loading: false,
        pipeline_marking_active: false,
        top_level_combos: nil,
        alive_pipelines: []
      )

    {:ok, socket}
  end

  # updates charts and reloads dagree when live update is enabled
  @impl true
  def handle_params(%{"mode" => "update", "from" => from, "to" => to}, _session, socket) do
    empty_lists = for _metric <- 1..length(socket.assigns.metrics), do: []

    # if we have no data assigned then request the full query
    if socket.assigns.data == empty_lists do
      push_patch_with_params(socket, %{from: from, to: to}) |> noreply()
    else
      with true <- connected?(socket),
           {from, to} <- extract_time_range(%{"from" => from, "to" => to}, socket) do
        launch_query_task(socket, socket.assigns, from, to, :update) |> noreply()
      else
        _ ->
          socket
          |> plan_update()
          |> noreply()
      end
    end
  end

  # reloads full charts and dagre after pressing any button or reloading page
  def handle_params(params, _session, socket) do
    with true <- connected?(socket),
         {from, to} <- extract_time_range(params, socket),
         accuracy <- extract_accuracy(params, socket),
         update <- extract_update_status(params, socket),
         update_range <- extract_update_time_range(params, socket) do
      socket
      |> launch_query_task(
        %{metrics: socket.assigns.metrics, accuracy: accuracy},
        from,
        to,
        :full
      )
      |> assign(
        accuracy: accuracy,
        update: update,
        update_range: update_range
      )
      |> noreply()
    else
      something ->
        Logger.error("Encountered invalid arguments when handling params: #{inspect(something)}")
        noreply(socket)
    end
  end

  # inits, realoads or updates charts and reloads dagre
  @impl true
  def handle_info({:charts_init, data}, socket) do
    socket
    |> push_event("charts_init", %{data: data})
    |> noreply()
  end

  def handle_info({event, charts, paths, accumulators}, socket)
      when event in [:charts_data, :charts_update] do
    socket
    |> push_event(Atom.to_string(event), %{data: charts})
    |> assign(data: Enum.map(charts, & &1.data), paths: paths, data_accumulators: accumulators)
    |> noreply()
  end

  def handle_info({:alive_pipelines, alive_pipelines}, socket) do
    socket
    |> assign(alive_pipelines: alive_pipelines)
    |> noreply()
  end

  # this message is the last message sent from query task
  def handle_info({:update_query_time, time_from, time_to}, socket) do
    socket
    |> assign(time_from: time_from, time_to: time_to)
    |> case do
      # if the timer had not been set then do nothing
      %{assigns: %{update_ref: nil}} = socket ->
        socket

      socket ->
        socket |> plan_update()
    end
    |> noreply()
  end

  def handle_info({:dagre_data, data}, socket) do
    socket
    |> push_event("dagre_data", %{data: data})
    |> noreply()
  end

  def handle_info({:set_data_loading, loading}, socket) do
    socket
    |> assign(data_loading: loading)
    |> noreply()
  end

  def handle_info(:update, socket) do
    socket
    |> push_patch_with_params(%{
      mode: :update,
      from: now(-socket.assigns.update_range),
      to: now()
    })
    |> noreply()
  end

  def handle_info(
        {:DOWN, query_task_ref, :process, _pid, _reason},
        %{assigns: %{query_task_ref: query_task_ref}} = socket
      ) do
    socket
    |> assign(query_task_ref: nil)
    |> noreply()
  end

  @impl true
  def handle_event("refresh", %{"timeFrom" => time_from, "timeTo" => time_to}, socket) do
    case parse_time_range(time_from, time_to) do
      {:ok, {from, to}} ->
        socket
        |> push_patch_with_params(%{from: from, to: to, update: false})
        |> cancel_update()

      {:error, reason} ->
        put_flash(socket, :error, reason)
    end
    |> noreply()
  end

  def handle_event("last-x-min", %{"value" => minutes}, socket) do
    case Integer.parse(minutes) do
      {minutes_as_int, ""} ->
        push_patch_with_params(socket, %{
          from: now(-60 * minutes_as_int),
          to: now(),
          update: true,
          update_range: 60 * minutes_as_int
        })

      _ ->
        put_flash(socket, :error, ~s(Invalid format of "Last x minutes"))
    end
    |> noreply()
  end

  def handle_event("toggle-update-mode", _value, socket) do
    if socket.assigns.update do
      cancel_update(socket)
    else
      plan_update(socket)
    end
    |> assign(update: !socket.assigns.update)
    |> noreply()
  end

  def handle_event("toggle-pipeline-marking", _value, socket) do
    socket
    |> assign(pipeline_marking_active: !socket.assigns.pipeline_marking_active)
    |> noreply()
  end

  def handle_event("apply-accuracy", %{"accuracy" => accuracy}, socket) do
    {accuracy, ""} = Integer.parse(accuracy)

    socket
    |> push_patch_with_params(%{
      accuracy: accuracy,
      from: socket.assigns.time_from,
      to: socket.assigns.time_to
    })
    |> noreply()
  end

  def handle_event("top-level-combos", combos, socket),
    do: socket |> assign(top_level_combos: combos) |> noreply()

  def handle_event("select-alive-pipeline:" <> pipeline, _value, socket) do
    if socket.assigns.pipeline_marking_active do
      case Membrane.Dashboard.PipelineMarking.mark_dead(pipeline) do
        {inserted, nil} when inserted > 0 ->
          assign(socket,
            pipeline_marking_active: false,
            alive_pipelines: socket.assigns.alive_pipelines |> Enum.reject(&(&1 == pipeline))
          )

        _ ->
          assign(socket, pipeline_marking_active: false)
      end
    else
      socket
    end
    |> noreply()
  end

  def handle_event("focus-combo:" <> combo_id, _value, socket) do
    socket
    |> push_event("focus_combo", %{id: combo_id})
    |> noreply()
  end

  @doc """
  Changes UNIX time to ISO 8601 format.
  """
  @spec format_time(non_neg_integer()) :: String.t()
  def format_time(time) do
    time
    |> Helpers.add_to_beginning_of_time()
    |> DateTime.to_iso8601()
  end

  # returns current UNIX time with optional offset
  defp now(offset \\ 0) do
    DateTime.utc_now()
    |> DateTime.add(offset)
    |> DateTime.to_unix(:millisecond)
  end

  # next update will be in `@update_time` seconds
  defp plan_update(socket) do
    unless is_nil(socket.assigns.update_ref) do
      Process.cancel_timer(socket.assigns.update_ref)
    end

    ref = Process.send_after(self(), :update, @update_time * 1000)
    assign(socket, update_ref: ref)
  end

  defp cancel_update(socket) do
    if is_nil(socket.assigns.update_ref) do
      socket
    else
      Process.cancel_timer(socket.assigns.update_ref)

      assign(socket, update_ref: nil)
    end
  end

  defp launch_query_task(socket, assigns, time_from, time_to, mode) do
    live_view_pid = self()

    task_ref =
      spawn(fn ->
        send(live_view_pid, {:set_data_loading, true})
        {:ok, dagre} = Dagre.query(time_from, time_to)
        send(live_view_pid, {:dagre_data, dagre})

        if mode == :update do
          {:ok, {charts, paths, accumulators}} = ChartsUpdate.query(assigns, time_from, time_to)

          send(live_view_pid, {:charts_update, charts, paths, accumulators})
        else
          {:ok, {charts, paths, accumulators}} =
            ChartsFull.query(assigns.metrics, time_from, time_to, assigns.accuracy)

          send(live_view_pid, {:charts_data, charts, paths, accumulators})
        end

        alive_pipelines =
          Membrane.Dashboard.PipelineMarking.list_alive_pipelines(
            time_to
            |> DateTime.from_unix!(:millisecond)
            |> DateTime.to_naive()
          )

        send(live_view_pid, {:alive_pipelines, alive_pipelines})

        send(live_view_pid, {:update_query_time, time_from, time_to})
        send(live_view_pid, {:set_data_loading, false})
      end)
      |> Process.monitor()

    assign(socket, query_task_ref: task_ref)
  end

  # returns pair of UNIX time values made from strings in params or extracted from assigns in socket
  defp extract_time_range(%{"from" => from, "to" => to}, _socket),
    do: {String.to_integer(from), String.to_integer(to)}

  defp extract_time_range(_params, socket),
    do: {socket.assigns.time_from, socket.assigns.time_to}

  # returns accuracy extracted from strings in params or from assigns in socket
  defp extract_accuracy(%{"accuracy" => accuracy}, _socket),
    do: String.to_integer(accuracy)

  defp extract_accuracy(_params, socket),
    do: socket.assigns.accuracy

  # returns information whether the charts should be updated in real time
  defp extract_update_status(%{"update" => update}, _socket) do
    case update do
      "true" -> true
      _ -> false
    end
  end

  defp extract_update_status(_params, socket),
    do: socket.assigns.update_ref != nil

  # returns number of seconds in charts' time range; important for live update
  defp extract_update_time_range(%{"update_range" => update_range}, _socket),
    do: String.to_integer(update_range)

  defp extract_update_time_range(_params, socket),
    do: socket.assigns.update_range

  # returns pair of UNIX time values from DateTime in ISO 8601 format
  defp parse_time_range(from, to) do
    with [{:ok, from, _from_offset}, {:ok, to, _to_offset}] <-
           [from, to] |> Enum.map(&DateTime.from_iso8601/1),
         [unix_from, unix_to] <- [from, to] |> Enum.map(&DateTime.to_unix(&1, :millisecond)) do
      if unix_to > unix_from do
        {:ok, {unix_from, unix_to}}
      else
        {:error, "\"from\" should be before \"to\""}
      end
    else
      _ -> {:error, "Invalid time range format"}
    end
  end

  # executes push_patch/2 function with given `params` to invoke handle_params/3
  defp push_patch_with_params(socket, params),
    do: push_patch(socket, to: Routes.live_path(socket, __MODULE__, params))

  defp noreply(socket) do
    {:noreply, socket}
  end
end
