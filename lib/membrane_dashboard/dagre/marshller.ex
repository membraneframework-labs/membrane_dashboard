defmodule Membrane.Dashboard.Dagre.Marshaller do
  @type link_t :: %{
          parent_path: String.t(),
          from: String.t(),
          to: String.t(),
          pad_from: String.t(),
          pad_to: String.t()
        }

  @callback run([link_t()], elements_liveliness :: [new: MapSet.t(), dead: MapSet.t(), existing: MapSet.t()]) :: {:ok, any()} | {:error, any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Membrane.Dashboard.Dagre.Marshaller

      @spec bin_itself() :: String.t()
      def bin_itself(), do: "{Membrane.Bin, :itself}"
    end
  end
end
