defmodule Membrane.DashboardWeb.DashboardLive do
  use Membrane.DashboardWeb, :live_view

  alias Membrane.Dashboard.{Dagre, Metrics, Helpers}
  alias Membrane.Dashboard.Charts.Full, as: ChartsFull
  alias Membrane.Dashboard.Charts.Update, as: ChartsUpdate
  alias Membrane.DashboardWeb.Router.Helpers, as: Routes

  require Logger

  @initial_time_offset 300
  @initial_accuracy 10
  @update_time 5000

  # initially:
  # - time range is the last `@initial_time_offset` seconds
  # - live update is enabled
  # - charts are created based on current metrics in database
  # - `paths` and `data` needed for live update have lists of empty lists
  @impl true
  def mount(_params, _session, socket) do
    {:ok, metrics} = Metrics.query()
    empty_lists = for _metric <- 1..length(metrics), do: []

    send(self(), {:charts_init, metrics})
    Process.send_after(self(), :update, @update_time)

    {:ok,
     assign(socket,
       top_level_combos: nil,
       metrics: metrics,
       paths: empty_lists,
       data: empty_lists,
       time_from: now(-@initial_time_offset),
       time_to: now(),
       accuracy: @initial_accuracy,
       update: true,
       update_range: @initial_time_offset
     )}
  end

  # updates charts and reloads dagre when live update is enabled
  @impl true
  def handle_params(%{"mode" => "update", "from" => from, "to" => to}, _session, socket) do
    if socket.assigns.data == [[], []] do
      {:noreply, push_patch_with_params(socket, %{from: from, to: to})}
    else
      with true <- connected?(socket),
           {from, to} <- extract_time_range(%{"from" => from, "to" => to}, socket),
           {:ok, dagre} <- Dagre.query(from, to),
           {:ok, {charts, data, paths}} <-
             ChartsUpdate.query(socket, from, to) do
        send(self(), {:dagre_data, dagre})
        send(self(), {:charts_update, charts})

        {:noreply, assign(socket, paths: paths, data: data, time_from: from, time_to: to)}
      else
        {:error, reason} ->
          Logger.error(reason)
          {:noreply, socket}

        _ ->
          {:noreply, socket}
      end
    end
  end

  # reloads full charts and dagre after pressing any button or reloading page
  def handle_params(params, _session, socket) do
    with true <- connected?(socket),
         {from, to} <- extract_time_range(params, socket),
         accuracy <- extract_accuracy(params, socket),
         update <- extract_update_status(params, socket),
         update_range <- extract_update_time_range(params, socket),
         {:ok, dagre} <- Dagre.query(from, to),
         {:ok, charts, paths} <- ChartsFull.query(socket.assigns.metrics, from, to, accuracy) do
      send(self(), {:dagre_data, dagre})
      send(self(), {:charts_data, charts})

      data =
        charts
        |> Enum.map(fn chart -> chart[:data] end)

      {:noreply,
       assign(socket,
         paths: paths,
         data: data,
         time_from: from,
         time_to: to,
         accuracy: accuracy,
         update: update,
         update_range: update_range
       )}
    else
      {:error, reason} ->
        Logger.error(reason)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  # inits, realoads or updates charts and reloads dagre
  @impl true
  def handle_info({:charts_init, data}, socket),
    do: {:noreply, push_event(socket, "charts_init", %{data: data})}

  def handle_info({:charts_data, data}, socket),
    do: {:noreply, push_event(socket, "charts_data", %{data: data})}

  def handle_info({:charts_update, data}, socket),
    do: {:noreply, push_event(socket, "charts_update", %{data: data})}

  def handle_info({:dagre_data, data}, socket),
    do: {:noreply, push_event(socket, "dagre_data", %{data: data})}

  def handle_info(:update, socket) do
    Process.send_after(self(), :update, @update_time)

    if socket.assigns.update do
      {:noreply,
       push_patch_with_params(socket, %{
         mode: :update,
         from: now(-socket.assigns.update_range),
         to: now()
       })}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("refresh", %{"timeFrom" => time_from, "timeTo" => time_to}, socket) do
    with {:ok, {from, to}} <- parse_time_range(time_from, time_to) do
      {:noreply, push_patch_with_params(socket, %{from: from, to: to, update: false})}
    else
      {:error, reason} -> {:noreply, socket |> put_flash(:error, reason)}
    end
  end

  def handle_event("last-x-min", %{"value" => minutes}, socket) do
    with {minutes_as_int, ""} <- Integer.parse(minutes) do
      {:noreply,
       push_patch_with_params(socket, %{
         from: now(-60 * minutes_as_int),
         to: now(),
         update: true,
         update_range: 60 * minutes_as_int
       })}
    else
      _ -> {:noreply, socket |> put_flash(:error, "Invalid format of \"Last x minutes\"")}
    end
  end

  def handle_event("apply-accuracy", %{"accuracy" => accuracy}, socket) do
    with {:ok, accuracy} <- check_accuracy(accuracy) do
      {:noreply, push_patch_with_params(socket, %{accuracy: accuracy})}
    else
      {:error, _reason} -> {:noreply, socket}
    end
  end

  def handle_event("validate-accuracy", %{"accuracy" => accuracy}, socket) do
    with {:ok, _accuracy} <- check_accuracy(accuracy) do
      {:noreply, socket}
    else
      {:error, reason} -> {:noreply, socket |> put_flash(:error, reason)}
    end
  end

  def handle_event("top-level-combos", combos, socket),
    do: {:noreply, assign(socket, top_level_combos: combos)}

  def handle_event("focus-combo:" <> combo_id, _value, socket),
    do: {:noreply, push_event(socket, "focus_combo", %{id: combo_id})}

  @doc """
  Changes UNIX time to ISO 8601 format.
  """
  @spec format_time(non_neg_integer()) :: String.t()
  def format_time(time),
    do: time |> Helpers.add_to_beginning_of_time() |> DateTime.to_iso8601()

  # returns current UNIX time with optional offset
  defp now(offset \\ 0) do
    DateTime.utc_now()
    |> DateTime.add(offset)
    |> DateTime.to_unix(:millisecond)
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
    do: socket.assigns.update

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

  # checks whether the accuracy is a positive integer
  defp check_accuracy(accuracy) do
    {int, rest} = Integer.parse(accuracy)

    cond do
      int < 1 -> {:error, "Accuracy have to be a positive number"}
      rest != "" -> {:error, "Accuracy have to be an integer"}
      true -> {:ok, int}
    end
  end

  # executes push_patch/2 function with given `params` to invoke handle_params/3
  defp push_patch_with_params(socket, params),
    do: push_patch(socket, to: Routes.live_path(socket, __MODULE__, params))
end
