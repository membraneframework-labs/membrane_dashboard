defmodule Membrane.Dashboard.Charts do
  @type chart_data_t :: %{
          series: [%{label: String.t()}],
          data: [[integer()]]
        }
  @type chart_paths_t :: [String.t()]
  @type chart_accumulator_t :: map()
end
