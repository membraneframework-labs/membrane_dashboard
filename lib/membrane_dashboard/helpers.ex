defmodule Membrane.Dashboard.Helpers do
  @beginning_of_time ~U[1970-01-01 00:00:00Z]

  def parse_time(time) when is_number(time),
    do: Membrane.Dashboard.Helpers.add_to_beginning_of_time(time)

  @doc """
  Adds given time * unit to beginning of UNIX time.
  """
  @spec add_to_beginning_of_time(non_neg_integer(), System.time_unit()) :: DateTime.t()
  def add_to_beginning_of_time(time, unit \\ :millisecond) do
    @beginning_of_time |> DateTime.add(time, unit)
  end
end
