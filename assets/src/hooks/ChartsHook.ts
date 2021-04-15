import uPlot, { AlignedData, Series } from "uPlot";

import { ViewHookInterface } from "phoenix_live_view";
import { createCharts } from "../utils/charts";

type Hook = ViewHookInterface & {
  storeChart: uPlot;
  takeAndDemandChart: uPlot;
};

interface ChartsData {
  series: Series[];
  data: AlignedData;
}

interface IncomingData {
  data: ChartsData;
}

const ChartsHook = {
  mounted(this: Hook) {
    console.log("Mounting charts");
    const width = this.el.scrollWidth - 20;
    const height = this.el.scrollHeight;

    const chart = createCharts(this.el, width, height);
    this.storeChart = chart;

    this.handleEvent("charts_data", (payload) => {
      console.log("Received charts data");
      const chartsData = (payload as IncomingData).data;

      while (this.storeChart.series.length > 1) {
        this.storeChart.delSeries(1);
      }
      this.storeChart.delSeries(0);

      chartsData.series[0].value = (_, rawValue) => {
        const data = new Date(rawValue * 1000);
        return uPlot.fmtDate("{YYYY}-{MM}-{DD} {H}:{mm}:{ss}")(data);
      };

      for (const series of chartsData.series) {
        const color = randomColor();
        series.stroke = color;
        series.paths = (u) => null;
        series.points = {
          space: 0,
          fill: color,
        };
        this.storeChart.addSeries(series);
      }

      this.storeChart.setData(chartsData.data);
    });
  },
};

function randomColor(): string {
  return `#${randomHexNumber(64, 255)}${randomHexNumber(64, 255)}${randomHexNumber(64, 255)}`;
}

function randomHexNumber(min: number, max: number): string {
  const first =
    Math.floor(Math.random() * (Math.floor(max / 16) - Math.floor(min / 16))) +
    Math.floor(min / 16);
  const second = Math.floor(Math.random() * 16);
  return first.toString(16) + second.toString(16);
}

export default ChartsHook;
