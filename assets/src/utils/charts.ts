/* eslint new-cap: ["error", { "newIsCapExceptions": ["uPlot"] }] */

import uPlot, { AlignedData } from "uplot";

import { getXTicksConfig } from "../utils/chartsXTicksConfig";

const metricToTitle: Record<string, string> = {
  caps: "Processed caps",
  event: "Processed events",
  store: "Input buffer size inside store/3",
  take_and_demand: "Input buffer size inside take_and_demand/4",
  queue_len: "Message queue size (measured during buffer callback)",
  buffer: "Processed buffers per second (measured during buffer callback)",
  bitrate: "Processed bytes per second (measured during buffer callback)"
};

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
      title: metricToTitle[metric] ?? metric,
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
