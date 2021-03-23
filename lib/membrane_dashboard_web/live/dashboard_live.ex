defmodule Membrane.DashboardWeb.DashboardLive do
  use Membrane.DashboardWeb, :live_view

  alias Membrane.Dashboard.Dagre
  alias Membrane.DashboardWeb.Router.Helpers, as: Routes

  @time_range_regex Regex.compile!("^from=([0-9]+)&to=([0-9]+)$")

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       time_range: "",
       top_level_combos: nil,
       time_from: nil,
       time_to: nil
     )}
  end

  @impl true
  def handle_params(params, _session, socket) do
    with true <- connected?(socket),
    {:ok, {from, to}} <- parse_time_range(params),
         {:ok, dagre} <- Dagre.query_dagre(from, to) do
      send(self(), {:dagre_data, dagre})
      {:noreply, assign(socket, time_range: "", time_from: from, time_to: to)}
    else
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:dagre_data, data}, socket) do
    {:noreply, push_event(socket, "dagre_data", %{data: data})}
  end

  @impl true
  def handle_event("validate-time-range", %{"timeRange" => time_range}, socket) do
    with {:ok, _} <- parse_time_range(time_range) do
      {:noreply, assign(socket, time_range: time_range)}
    else
      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, reason)}
    end
  end

  def handle_event("refresh", _values, socket) do
    with {:ok, {from, to}} <- parse_time_range(socket.assigns.time_range) do
      {:noreply,
       push_patch(socket, to: Routes.live_path(socket, __MODULE__, %{from: from, to: to}))}
    else
      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("top-level-combos", combos, socket) do
    {:noreply, assign(socket, top_level_combos: combos)}
  end

  def handle_event("focus-combo:" <> combo_id, _value, socket) do
    {:noreply, push_event(socket, "focus_combo", %{id: combo_id})}
  end

  def format_time(time) do
    ~U[1970-01-01 00:00:00Z] |> DateTime.add(time, :millisecond) |> DateTime.to_iso8601()
  end

  defp parse_time_range(%{"from" => from, "to" => to}) do
    [from, to] = [from, to] |> Enum.map(&String.to_integer/1)

    {:ok, {from, to}}
  end

  defp parse_time_range(%{}) do
    {:error, "Time range params are missing"}
  end

  defp parse_time_range(time_range) when is_binary(time_range) do
    with [_, from, to] <- Regex.run(@time_range_regex, time_range) do
      [from, to] = [from, to] |> Enum.map(&String.to_integer/1)
      {:ok, {from, to}}
    else
      _ ->
        {:error, "Invalid time range format"}
    end
  end
end
