defmodule Membrane.Dashboard.Metrics do
  @moduledoc """
  Module responsible for extracting list of metrics measured and put to TimescaleDB.
  """

  alias Membrane.Dashboard.Repo

  @doc """
  Queries database to get list of metrics from measurements table.
  """
  @spec query() :: {:ok, [String.t()]}
  def query() do
    result =
      """
      SELECT DISTINCT metric
      FROM measurements
      ORDER BY metric
      """
      |> Repo.query()

    with {:ok, %Postgrex.Result{rows: rows}} <- result do
      {:ok, List.flatten(rows)}
    else
      _ -> {:ok, []}
    end
  end
end
