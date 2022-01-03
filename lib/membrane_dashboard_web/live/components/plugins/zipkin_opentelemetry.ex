defmodule Membrane.DashboardWeb.Live.Components.Plugins.ZipkinOpentelemetry do
  @moduledoc """
  Component integrating a zipkin opentelemetry service. It allows to searching zipkin for potential
  traces and when one gets found it displays a button redirecting to zipkin's dashboard.

  ## Usage
  By default the component is hidden. To enable it one must set `USE_ZIPKIN` environmental variable to 'true'.
  To change default zipkin's url one can set `ZIPKIN_URL` env (defaults to `http://localhost:9411`).
  Changing the default span's tag name can be done via `ZIPKIN_TAG_NAME` env (defaults to `state_component_path`).

  ## How it works
  The only available information for finding a trace is the component path of pipeline/bin/element selected by the user.

  Given that any of trace's spans have an attribute linked with the given component path we should be able to find it.

  By default #{inspect(__MODULE__)} will try to find a trace having a `state_component_path` tag name with a path as a value.
  """

  use Membrane.DashboardWeb, :live_component

  import Membrane.DashboardWeb.Live.Helpers

  require Logger

  # NOTE: for now the only supported elements containing opentelemetry are related
  # to videoroom so just for now leave the constant here and potentially add ability
  # to set them dynamically in the future...
  @tag_name "state_component_path"

  @impl true
  def mount(socket) do
    {:ok, assign(socket, %{error: nil, not_found: false})}
  end

  @impl true
  def update(assigns, socket) do
    assigns =
      Map.merge(assigns, %{
        tag_name: System.get_env("ZIPKIN_TAG_NAME", @tag_name),
        base_url: base_url(),
        tag_value: "",
        trace_ids: nil,
        error: nil,
        not_found: false
      })

    socket = assign(socket, assigns)

    case extract_trace_ids(assigns.active_path, @tag_name) do
      {:ok, trace_ids, tag_value} ->
        {:ok, assign(socket, %{trace_ids: trace_ids, tag_value: tag_value})}

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
        tooltip="Based on selected path tries querying zipkin instance to find a related trace. For more info check documentation."
      />
      <div class="flex flex-col bg-secondary rounded-lg p-3">
        <div class="flex adjust-center">
          <%= cond do %>
            <% @trace_ids != nil -> %>
              <%= for trace_id <- @trace_ids do %>
                <div class="flex items-center">
                  <span class="font-bold text-white mr-1">Trace:</span>
                  <span class="font-semibold text-gray-300 mr-3"><%= trace_id %></span>
                  <.tooltip text="Open in zipkin dashboard" class="-left-8 -top-8">
                    <button
                      x-on:click={"window.open('#{dashboard_url(@base_url, trace_id)}')"}
                      type="button"
                      class="default-button" phx-update="ignore"
                    >
                      <.opentelemetry_icon class="text-white h-7 w-7 mr-3" />
                      <span class="text-white text-md">View</span>
                    </button>
                  </.tooltip>
                </div>
              <% end %>

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

  defp extract_trace_ids([], _tag_name), do: {:ok, nil, ""}

  # Given a path tries to match on the longest subpath where any trace can be found.
  # e.g. given a path of '[a, b, c, d]' it will query:
  # [a, b, c, d] -> [a, b, c] -> [a, b] -> [a], and it will
  # stop on the first match where a trace gets found
  defp extract_trace_ids(path, tag_name) do
    # start with a reversed path as it is easier to get a tail
    # from a list rather than deleting the last element
    reversed_path = Enum.reverse(path)

    acc = {{:error, :not_found}, reversed_path}

    Enum.reduce_while(1..length(path), acc, fn _i, {_error, reversed_path} ->
      path =
        reversed_path
        |> Enum.reverse()
        |> Enum.join("/")

      path
      |> do_extract_trace_ids(tag_name)
      |> case do
        {:ok, trace_ids, tag_value} ->
          {:halt, {:ok, trace_ids, tag_value}}

        error ->
          {:cont, {error, tl(reversed_path)}}
      end
    end)
    |> case do
      {:ok, _trace_id, _tag_value} = result -> result
      {{:error, _reason} = error, _path} -> error
    end
  end

  defp do_extract_trace_ids("", _tag_name), do: {:ok, nil}

  defp do_extract_trace_ids(path, tag_name) do
    with tag_value <- tag_value_from_path(path),
         {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
           HTTPoison.get(api_query_url(base_url(), tag_name, tag_value)),
         {:ok, trace} <- Jason.decode(body),
         {:ok, trace_ids} <- find_trace_ids(trace) do
      {:ok, trace_ids, tag_value}
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

  # paths constructed by reporter contain a VM's process id which is not present in
  # trace's tag values, therefore we need to get rid of that
  # e.g. 'pipeline@1111@<100.0>/some_path' -> 'pipeline@<100.0>/some_path' (delete '@1111' which is a VM's process id)
  def tag_value_from_path(path) do
    Regex.replace(~r/(pipeline@)([0-9]+@)(.*)/, path, "\\1\\3")
  end

  defp base_url() do
    System.get_env("ZIPKIN_URL", "http://localhost:9411")
  end

  defp api_query_url(base_url, tag_name, tag_value) do
    [
      base_url,
      "/zipkin/api/v2/traces",
      "?annotationQuery=",
      URI.encode_www_form("#{tag_name} and #{tag_name}=#{tag_value}"),
      "&limit=1"
    ]
    |> Enum.join()
  end

  defp dashboard_url(base_url, trace_id) do
    "#{base_url}/zipkin/traces/#{trace_id}"
  end

  defp find_trace_ids([]), do: {:error, :not_found}

  defp find_trace_ids(entries) when is_list(entries) do
    entries
    |> Enum.map(fn [%{"traceId" => trace_id} | _] -> trace_id end)
    |> then(&{:ok, &1})
  end
end
