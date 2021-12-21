defmodule Membrane.Dashboard.Charts do
  @moduledoc """
  Utility types for charts.
  """

  @typedoc """
  A type representing a single chart.

  ## Note
  The first series must be named `time` and the first row of data must
  consist of timestamps instead of proper values.
  """
  @type chart_data_t :: %{
          series: [%{label: String.t()}],
          data: [[integer()]]
        }

  @typedoc """
  A mapping from a `path_id` to the actual path's string representation.
  """
  @type chart_paths_t :: %{non_neg_integer() => String.t()}

  @typedoc """
  A map pointing from a `path_id` to its corresponding chart accumulator.
  """
  @type chart_accumulator_t :: map()
  @type chart_query_result_t ::
          {:ok, {chart_data_t(), chart_paths_t(), chart_accumulator_t()}} | {:error, any()}

  @type metric_t :: :caps | :event | :store | :take_and_demand | :buffer | :queue_len | :bitrate

  defmodule Context do
    @moduledoc """
    Common context structure for querying charting data, either as
    a FULL query or an UPDATE which takes into consideration already existing data.

    Fields necessary for both ot query types are:
    * `time_from` - initial timestamp to start querying from
    * `time_to` - ending timestamp up to which query should be performed
    * `accuracy` - number of millisecond between each chart step, unfortunately charts
      have to provide value for each time interval, no matter if the measurement happened or not,
      the lower accuracy value the more precise the chart will be but it will be much more CPU, memory and time intensive
      to create such chart
    * `metric` - a metric name that the query should be performed against


    Fields that are used and necessary just for UPDATE query:
    * `data` - resulting data from previous query,
    * `paths` - resulting paths from previous query #TODO: has to be verified, just a guess for now
    * `accumulators` - accumulators returned from previous FULL/UPDATE queries
    * `latest_time` - latest `time_to` parameter used for querying

    """

    alias Membrane.Dashboard.Charts

    @type t :: %__MODULE__{
            time_from: non_neg_integer(),
            time_to: non_neg_integer(),
            accuracy: non_neg_integer(),
            metric: String.t(),
            data: [Charts.chart_data_t()],
            paths_mapping: %{non_neg_integer() => String.t()},
            accumulators: [Charts.chart_accumulator_t()],
            latest_time: non_neg_integer() | nil
          }

    @enforce_keys [:time_from, :time_to, :accuracy, :metric]
    defstruct @enforce_keys ++ [data: [], paths_mapping: %{}, accumulators: [], latest_time: nil]
  end
end
