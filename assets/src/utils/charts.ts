import uPlot, { AlignedData } from "uPlot";
import { getXTicksConfig } from "../utils/chartsXTicksConfig";

export function createCharts(
  container: HTMLElement,
  width: number,
  method: string
): uPlot {
  const data: AlignedData = [[]];

  return new uPlot(
    {
      width: width,
      height: 200,
      title: `Input buffer size inside ${method}`,
      id: "chart1",
      class: "my-chart",
      series: [],
      axes: [
        {
          values: getXTicksConfig(),
          stroke: "#c7d0d9",
          grid: {
            stroke: "#2c3235",
          },
          ticks: {
            stroke: "#2c3235",
          },
        },
        {
          stroke: "#c7d0d9",
          grid: {
            stroke: "#2c3235",
          },
          ticks: {
            stroke: "#2c3235",
          },
        },
      ],
    },
    data,
    container
  );
}
