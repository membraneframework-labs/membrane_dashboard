defmodule Membrane.DashboardWeb.DashboardLive do
  use Membrane.DashboardWeb, :live_view

  alias Membrane.Dashboard.Dagre

  @impl true
  def mount(_params, _session, socket) do

    if connected?(socket) do
      case Dagre.query_dagre(1616145976898, 1616146004558) do
        {:ok, dagre} ->


          send(self(), {:dagre_data, dagre})
          {:ok, socket}

        {:error, reason} ->
          {:ok, socket |> put_flash(:error, reason)}
      end
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_info({:dagre_data, data}, socket) do
    {:noreply, push_event(socket, "dagre_data", %{data: data})}
  end
end
