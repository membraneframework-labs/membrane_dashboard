defmodule Membrane.DashboardWeb.Live.Components.AlivePipelines do
  @moduledoc """
  Component for displaying alive pipelines that further can be marked as dead
  if the application starting them unexpectedly crashed.
  """

  use Membrane.DashboardWeb, :live_component

  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok, assign(socket, is_marking_active: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <h3>Pipeline marking</h3>
      <p>It may happen that pipeline terminating has not been registered. Here you can manually mark pipeline as dead.</p>
      <div id="alive-pipelines" class="DagreCombos">
        <%= for pipeline <- @alive_pipelines do %>
          <div data-combo-id={pipeline} class={"Combo #{if not @is_marking_active, do: "unclickable", else: ""}"} phx-click={JS.push("pipelines:focus", value: %{pipeline: pipeline})} phx-target={@myself}>
            <%= pipeline %>
          </div>
        <% end %>
        <div class={if @is_marking_active, do: "PipelineMarkingActive", else: "PipelineMarkingInactive"} phx-click="pipelines:toggle-marking">
          <%= if @is_marking_active do %>
            Select pipeline
          <% else %>
            Mark pipeline as dead
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "pipelines:focus",
        %{value: %{pipeline: pipeline}},
        %{assigns: %{is_marking_active: true}} = socket
      ) do
    send_self({:mark_dead, pipeline})

    {:noreply, socket}
  end

  def handle_event("pipelines:focus", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("pipelines:toggle-marking", _params, socket) do
    socket
    |> assign(is_marking_active: !socket.assigns.is_marking_active)
    |> then(&{:noreply, &1})
  end

  # TODO: this should be put inside `use Membrane.DashboardWeb, :live_component`
  defp send_self(message) do
    send(self(), {:alive_pipelines, message})
  end
end
