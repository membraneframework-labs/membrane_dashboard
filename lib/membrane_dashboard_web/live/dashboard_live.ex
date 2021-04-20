defmodule Membrane.DashboardWeb.DashboardLive do
  use Membrane.DashboardWeb, :live_view

  alias Membrane.Dashboard.{Dagre, Charts, Methods, Helpers}
  alias Membrane.DashboardWeb.Router.Helpers, as: Routes

  @initial_time_offset 300
  @initial_accuracy 10

  # initial time range is the last '@initial_time_offset' seconds
  @impl true
  def mount(_params, _session, socket) do
    {:ok, methods} = Methods.query()
    send(self(), {:init_data, methods})

    {:ok,
     assign(socket,
       top_level_combos: nil,
       methods: methods,
       time_from: now(-@initial_time_offset),
       time_to: now(),
       accuracy: @initial_accuracy
     )}
  end

  # gets data for dagre and charts and assigns time range and accuracy to socket
  @impl true
  def handle_params(params, _session, socket) do
    with true <- connected?(socket),
         {:ok, {from, to}} <- extract_time_range(params, socket),
         {:ok, accuracy} <- extract_accuracy(params, socket),
         {:ok, dagre} <- Dagre.query(from, to),
         {:ok, charts} <- Charts.query(socket.assigns.methods, from, to, accuracy) do

      send(self(), {:dagre_data, dagre})
      send(self(), {:charts_data, charts})

      {:noreply, assign(socket, time_from: from, time_to: to, accuracy: accuracy)}
    else
      _ -> {:noreply, socket}
    end
  end

  # inits and refreshes dagre and charts
  @impl true
  def handle_info({:init_data, methods}, socket),
    do: {:noreply, push_event(socket, "init_data", %{data: methods})}

  def handle_info({:dagre_data, data}, socket),
    do: {:noreply, push_event(socket, "dagre_data", %{data: data})}

  def handle_info({:charts_data, data}, socket),
    do: {:noreply, push_event(socket, "charts_data", %{data: data})}

  @impl true
  def handle_event("refresh", %{"timeFrom" => time_from, "timeTo" => time_to}, socket) do
    with {:ok, {from, to}} <- parse_time_range(time_from, time_to) do
      {:noreply, push_patch_with_params(socket, %{from: from, to: to})}
    else
      {:error, reason} -> {:noreply, socket |> put_flash(:error, reason)}
    end
  end

  def handle_event("last-x-min", %{"value" => minutes}, socket) do
    with {minutes_as_int, ""} <- Integer.parse(minutes) do
      {:noreply, push_patch_with_params(socket, %{from: now(-60*minutes_as_int), to: now()})}
    else
      _ -> {:noreply, socket |> put_flash(:error, "Invalid format of \"Last x minutes\"")}
    end
  end

  def handle_event("apply-accuracy", %{"accuracy" => accuracy}, socket) do
    with {:ok, accuracy} <- check_accuracy(accuracy) do
      {:noreply, push_patch_with_params(socket, %{accuracy: accuracy})}
    else
      {:error, reason} -> {:noreply, socket}
    end
  end

  def handle_event("validate-accuracy", %{"accuracy" => accuracy}, socket) do
    with {:ok, accuracy} <- check_accuracy(accuracy) do
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

  @doc """
  Having accuracy and number of methods, returns expected rendering time as string ready to put to html.leex file.
  Based on very limited tests, so not too precise.
  """
  @spec expected_render_time(non_neg_integer(), list(String.t())) :: String.t()
  def expected_render_time(accuracy, methods) do
    min_expected = 50 * length(methods) / accuracy
    max_expected = 2 * min_expected
    "#{Float.round(min_expected, 2)} - #{Float.round(max_expected, 2)}"
  end

  # returns current UNIX time with optional offset
  defp now(offset \\ 0) do
    DateTime.utc_now()
    |> DateTime.add(offset)
    |> DateTime.to_unix(:milliseconds)
  end

  # returns pair of UNIX time values made from strings in params or extracted from assigns in socket
  defp extract_time_range(%{"from" => from, "to" => to}, _socket),
    do: {:ok, {String.to_integer(from), String.to_integer(to)}}

  defp extract_time_range(_params, socket),
    do: {:ok, {socket.assigns.time_from, socket.assigns.time_to}}

  # returns accuracy extracted from strings in params or from assigns in socket
  defp extract_accuracy(%{"accuracy" => accuracy}, _socket),
    do: {:ok, String.to_integer(accuracy)}

  defp extract_accuracy(_params, socket),
    do: {:ok, socket.assigns.accuracy}

  # returns pair of UNIX time values from DateTime in ISO 8601 format
  defp parse_time_range(from, to) do
    with [{:ok, from, _offset}, {:ok, to, _offset}] <- [from, to] |> Enum.map(&DateTime.from_iso8601/1),
         [unix_from, unix_to] <- [from, to] |> Enum.map(&(DateTime.to_unix(&1, :milliseconds))) do
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
      int < 1    -> {:error, "Accuracy have to be a positive number"}
      rest != "" -> {:error, "Accuracy have to be an integer"}
      true       -> {:ok, int}
    end
  end

  # executes push_patch/2 function with given 'params' to invoke handle_params/3
  defp push_patch_with_params(socket, params),
    do: push_patch(socket, to: Routes.live_path(socket, __MODULE__, params))
end
