defmodule Membrane.DashboardWeb.DashboardLive do
  use Membrane.DashboardWeb, :live_view

  alias Membrane.Dashboard.{Dagre, Charts, Helpers}
  alias Membrane.DashboardWeb.Router.Helpers, as: Routes

  @time_range_regex Regex.compile!("^from=([0-9]+)&to=([0-9]+)$")

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       time_range: nil,
       top_level_combos: nil,
       time_from: now(-300),
       time_to: now()
     )}
  end

  @impl true
  def handle_params(params, _session, socket) do
    with true <- connected?(socket),
         {:ok, {from, to}} <- parse_time_range(params),
         {:ok, dagre} <- Dagre.query_dagre(from, to),
         {:ok, charts} <- Charts.query_charts(from, to) do

      send(self(), {:dagre_data, dagre})
      send(self(), {:charts_data, charts})

      {:noreply, assign(socket, time_range: nil, time_from: from, time_to: to)}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:dagre_data, data}, socket) do
    {:noreply, push_event(socket, "dagre_data", %{data: data})}
  end

  def handle_info({:charts_data, data}, socket) do
    {:noreply, push_event(socket, "charts_data", %{data: data})}
  end

  @impl true
  def handle_event("refresh", %{"timeFrom" => time_from, "timeTo" => time_to}, socket) do
    with {:ok, {from, to}} <- parse_time_range(time_from, time_to) do
      {:noreply,
       push_patch(socket, to: Routes.live_path(socket, __MODULE__, %{from: from, to: to}))}
    else
      {:error, reason} -> {:noreply, socket |> put_flash(:error, reason)}
    end
  end

  def handle_event("last-5-min", _values, socket) do
    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, %{from: now(-300), to: now()}))}
  end

  def handle_event("last-10-min", _values, socket) do
    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, %{from: now(-600), to: now()}))}
  end

  def handle_event("top-level-combos", combos, socket) do
    {:noreply, assign(socket, top_level_combos: combos)}
  end

  def handle_event("focus-combo:" <> combo_id, _value, socket) do
    {:noreply, push_event(socket, "focus_combo", %{id: combo_id})}
  end

  def now(offset \\ 0) do
    DateTime.utc_now()
    |> DateTime.add(offset)
    |> DateTime.to_unix(:milliseconds)
  end

  def format_time(time) do
    time |> Helpers.add_to_beginning_of_time() |> DateTime.to_iso8601()
  end

  defp to_time_range(time_from, time_to) do
    "from=#{time_from}&to=#{time_to}"
  end

  defp parse_time_range(%{"from" => from, "to" => to}),
    do: {:ok, {String.to_integer(from), String.to_integer(to)}}

  defp parse_time_range(%{}),
    do: {:error, "Time range params are missing"}

  defp parse_time_range(time_range) when is_binary(time_range) do
    with [_, from, to] <- Regex.run(@time_range_regex, time_range) do
      [from, to] = [from, to] |> Enum.map(&String.to_integer/1)
      {:ok, {from, to}}
    else
      _ -> {:error, "Invalid time range format"}
    end
  end

  defp parse_time_range(time_from, time_to) do
    with [{:ok, date_time_from, _offset_from}, {:ok, date_time_to, _offset_to}] <- [time_from, time_to] |> Enum.map(&DateTime.from_iso8601/1),
         [from, to] <- [date_time_from, date_time_to] |> Enum.map(fn time -> DateTime.to_unix(time, :milliseconds) end) do
      cond do
        to > from -> {:ok, {from, to}}
        true      -> {:error, "\"from\" should be before \"to\""}
      end
    else
      _ -> {:error, "Invalid time range format"}
    end
  end
end
