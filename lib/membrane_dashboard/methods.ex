defmodule Membrane.Dashboard.Methods do
  @moduledoc """
  Module responsible for extracting list of methods for which input buffer size were measured and put in TimescaleDB.
  """

  alias Membrane.Dashboard.Repo

  @doc """
  Queries database to get list of methods from measurements table.
  """
  @spec query() :: {:ok, list(String.t())}
  def query() do
    result =
      """
      SELECT DISTINCT method
      FROM measurements
      ORDER BY method
      """
      |> Repo.query()

    {:ok, %Postgrex.Result{rows: rows}} = result
    methods = List.flatten(rows)
    {:ok, methods}
  end
end
