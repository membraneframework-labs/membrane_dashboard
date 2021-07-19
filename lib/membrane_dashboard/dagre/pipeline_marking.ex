defmodule Membrane.Dashboard.PipelineMarking do
  @moduledoc false

  import Ecto.Query

  alias Membrane.Dashboard.Repo
  alias Membrane.Dashboard.Helpers

  @doc """
  Given pipeline prefix tries to mark all elements, that belong to the given pipeline, as dead by creating
  entries in `elements` schema.
  """
  @spec mark_dead(String.t()) :: any()
  def mark_dead(pipeline) do
    search_string = pipeline <> "%"

    elements =
      from(el in "elements",
        where: ilike(el.path, ^search_string),
        select: el.path
      )
      |> Repo.all()
      |> Enum.map(
        &%{
          time: NaiveDateTime.utc_now(),
          path: &1,
          terminated: true
        }
      )

    Repo.insert_all("elements", elements)
  end

  @doc """
  Lists all element's paths for elements that have been alive till the `time_to` time.
  """
  @spec list_alive_pipelines(NaiveDateTime.t()) :: list(String.t())
  def list_alive_pipelines(time_to) do
    from(el in "elements",
      group_by: el.path,
      having: count(el.time) == 1 and min(el.time) < ^time_to,
      select: el.path
    )
    |> Repo.all()
    |> Enum.map(&(&1 |> String.split("/") |> List.first()))
    |> MapSet.new()
    |> MapSet.to_list()
  end
end
