defmodule Membrane.DashboardWeb.Live.Components.Plugins.ZipkinOpentelemetry do
  @moduledoc """
  Component integrating a zipkin opentelemetry service. It allows to searching zipkin for potential
  traces and when one gets found it displays a button redirecting to zipkin's dashboard.

  ## Usage
  By default the component is hidden. To enable it one must set `USE_ZIPKIN` environmental variable to 'true'.
  To change default zipkin's url one can set `ZIPKIN_URL` env (defaults to `http://localhost:9411`).

  ## How it works
  It works as follows:
  - define a tag's value regex (a regex with a single capture group responsible for catching the tag value) and a tag name necessary for querying the zipkin
  - receive active path of elements and join it into a single string
  - run the value regex against given path string
  - extract the value from the capture group and try to find a trace having tag of given name with the extracted value

  Example, let's say that we have the following variables:
  - regex - '{:endpoint, "(.+?)}'
  - tag_name - 'state_id'
  - path - 'pipeline@57176@<0.870.0>/{:endpoint, "6db9f56e-3941-467f-82b1-e65c8d898899"} bin/:endpoint_bin bin/:rtp bin/}'

  We know beforehand that our telemetry trace must have a `state_id` tag with a value representing an endpoint id.
  By matching the regex against the path we will extract '6db9f56e-3941-467f-82b1-e65c8d898899' id, next
  we are querying the zipkin instance with a condition where 'state_id={id}' and from the response we will extract
  the trace id (if the trace gets found). If the trace gets found then we display a redirect button.
  """

  use Membrane.DashboardWeb, :live_component

  import Membrane.DashboardWeb.Live.Helpers

  require Logger

  # NOTE: for now the only supported elements containing opentelemetry are related
  # to videoroom so just for now leave the constant here and potentially add ability
  # to set them dynamically in the future...
  @tag_name "state_id"
  @tag_value_regex Regex.compile!("{:endpoint, \"(.+?)\"}")

  @impl true
  def mount(socket) do
    {:ok, assign(socket, %{error: nil, not_found: false})}
  end

  @impl true
  def update(assigns, socket) do
    path = Enum.join(assigns.active_path, "/")

    assigns =
      Map.merge(assigns, %{
        regex: @tag_value_regex.source,
        tag_name: @tag_name,
        base_url: base_url(),
        path: path,
        trace_id: nil,
        error: nil,
        not_found: false
      })

    socket = assign(socket, assigns)

    case extract_trace_id(path, @tag_value_regex, @tag_name) do
      {:ok, trace_id} ->
        {:ok, assign(socket, :trace_id, trace_id)}

      {:error, :not_found} ->
        {:ok, assign(socket, :not_found, true)}

      {:error, message} ->
        {:ok, assign(socket, :error, message)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="mb-3">
      <.info_header
        title="Zipkin OpenTelemetry"
        tooltip="Given a regex (with a single capture group) and a tag name extracts tag value from selected path and based on that tries querying zipkin instance to find a related trace."
      />
      <div class="flex flex-col bg-secondary rounded-lg p-3">
        <div class="flex mb-3">
          <div class="mr-3 flex justify-center items-center">
            <label class="text-white font-bold mr-2">Regex</label>
            <input
              disabled
              type="text"
              value={@regex}
              name="regex"
              phx-debounce="blur"
              class="default-input"
            />
          </div>
          <div class="mr-3 flex justify-center items-center">
            <label class="text-white font-bold mr-2">Tag name</label>
            <input
              disabled
              type="text"
              value={@tag_name}
              name="tag_name"
              phx-debounce="blur"
              class="default-input"
            />
          </div>
        </div>
        <div class="flex items-center">
          <%= cond do %>
            <% @trace_id -> %>
              <span class="font-bold text-white mr-1">Trace:</span>
              <span class="font-semibold text-gray-300 mr-3"><%= @trace_id %></span>
              <.tooltip text="Open in zipkin dashboard" class="-left-8 -top-8">
                <button
                  x-on:click={"window.open('#{dashboard_url(@base_url, @trace_id)}')"}
                  type="button"
                  class="default-button" phx-update="ignore"
                >
                  <.opentelemetry_icon class="text-white h-7 w-7 mr-3" />
                  <span class="text-white text-md">View</span>
                </button>
              </.tooltip>

            <% @error != nil -> %>
              <span class="error"><%= @error %></span>

            <% @not_found == true -> %>
              <span class="description">No trace has been found</span>

            <% true -> %>
              <span class="description">No path selected...</span>

          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp extract_trace_id("", _tag_regex, _tag_name), do: {:ok, nil}

  defp extract_trace_id(path, tag_regex, tag_name) do
    with {:extract, [_, tag_value]} <- Regex.run(tag_regex, path) |> then(&{:extract, &1}),
         {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
           HTTPoison.get(api_query_url(base_url(), tag_name, tag_value)),
         {:ok, trace} <- Jason.decode(body),
         {:ok, trace_id} <- find_trace_id(trace) do
      {:ok, trace_id}
    else
      {:extract, _} ->
        {:error, "Failed to extract tag value for path: '#{path}'."}

      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, %HTTPoison.Response{}} ->
        {:error, "Invalid zipkin's response. Make sure you are using a valid zipkin's url."}

      {:error, %HTTPoison.Error{}} ->
        {:error, "Failed to connect to zipkin instance, check if it is actually running."}

      other ->
        Logger.error(
          "#{inspect(__MODULE__)} Failed to match extract_trace_id/1, got: #{inspect(other)}"
        )

        {:error, "Unknown error, check dashboard terminal"}
    end
  end

  defp base_url() do
    System.get_env("ZIPKIN_URL", "http://localhost:9411")
  end

  defp api_query_url(base_url, tag_name, tag_value) do
    [
      base_url,
      "/zipkin/api/v2/traces",
      "?annotationQuery=",
      URI.encode_www_form("#{tag_name} and #{tag_name}=#{tag_value}") <> "&limit=1"
    ]
    |> Enum.join()
  end

  defp dashboard_url(base_url, trace_id) do
    "#{base_url}/zipkin/traces/#{trace_id}"
  end

  defp find_trace_id([]), do: {:error, :not_found}

  defp find_trace_id([[%{"traceId" => trace_id} | _entries]]), do: {:ok, trace_id}
end
