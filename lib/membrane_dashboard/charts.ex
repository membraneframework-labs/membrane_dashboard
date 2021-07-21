defmodule Membrane.Dashboard.Charts do
  @moduledoc """
  Utility types for charts.
  """

  @type chart_data_t :: %{
          series: [%{label: String.t()}],
          data: [[integer()]]
        }
  @type chart_paths_t :: [String.t()]
  @type chart_accumulator_t :: map()
  @type chart_query_result_t ::
          {:ok, {[chart_data_t()], [chart_paths_t()], [chart_accumulator_t()]}} | {:error, any()}
end
