/* eslint new-cap: ["error", { "newIsCapExceptions": ["uPlot"] }] */

import uPlot, { AlignedData } from "uplot";
import { getXTicksConfig } from "../utils/chartsXTicksConfig";

const metricToTitle = new Map([
  ["caps", "Processed caps"],
  ["event", "Processed events"],
  ["store", "Input buffer size inside store/3"],
  ["take_and_demand", "Input buffer size inside take_and_demand/4"],
]);

export function createCharts(
  container: HTMLElement,
  width: number,
  metric: string
): uPlot {
  const data: AlignedData = [[]];

  return new uPlot(
    {
      width: width,
      height: 200,
      title: getChartTitle(metric),
      id: metric,
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

function getChartTitle(metric: string): string {
  const title = metricToTitle.get(metric);
  if (title) {
    return title;
  } else {
    return metric;
  }
}
