defmodule Membrane.Dashboard.Helpers do
  @doc """
  Adds given time * unit to beginning of UNIX time.
  """
  @spec add_to_beginning_of_time(non_neg_integer(), System.time_unit()) :: DateTime.t()
  def add_to_beginning_of_time(time, unit \\ :millisecond) do
    ~U[1970-01-01 00:00:00Z] |> DateTime.add(time, unit)
  end
end
