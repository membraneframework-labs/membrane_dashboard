import uPlot, { AlignedData, Series } from "uPlot";

import { ViewHookInterface } from "phoenix_live_view";
import { createCharts } from "../utils/charts";

type Hook = ViewHookInterface & {
  charts: uPlot[];
};

interface ChartData {
  series: Series[];
  data: AlignedData;
}

interface InitData {
  data: string[];
}

interface RefreshData {
  data: ChartData[];
}

const ChartsHook = {
  mounted(this: Hook) {
    console.log("Mounting charts");
    this.charts = [];

    // creating empty charts with proper names and sizes
    this.handleEvent("init_data", (payload) => {
      const width = this.el.scrollWidth - 20;
      const methods = (payload as InitData).data;
      for (const method of methods) {
        const chart = createCharts(this.el, width, method);
        this.charts.push(chart);
      }
    });

    this.handleEvent("charts_data", (payload) => {
      console.log("Received charts data");
      const chartsData = (payload as RefreshData).data;

      for (var i = 0; i < chartsData.length; i++) {
        // new series can be different from old ones, so all old series should be deleted
        while (this.charts[i].series.length > 1) {
          this.charts[i].delSeries(1);
        }
        this.charts[i].delSeries(0);

        // sets x axis ticks and converts them to milliseconds and then to readable datetime format
        const formatter = uPlot.fmtDate("{YYYY}-{MM}-{DD} {H}:{mm}:{ss}");
        chartsData[i].series[0].value = (_, rawValue) => {
          return formatter(new Date(rawValue * 1000));
        };

        // configures series and add them to the chart
        for (const series of chartsData[i].series) {
          const color = randomColor();
          series.stroke = color;
          series.paths = (_) => null;
          series.points = {
            space: 0,
            fill: color,
          };
          this.charts[i].addSeries(series);
        }

        this.charts[i].setData(chartsData[i].data);
      }
    });
  },
};

function randomColor(): string {
  return `#${randomHexNumber(64, 255)}${randomHexNumber(
    64,
    255
  )}${randomHexNumber(64, 255)}`;
}

function randomHexNumber(min: number, max: number): string {
  const first =
    Math.floor(Math.random() * (Math.floor(max / 16) - Math.floor(min / 16))) +
    Math.floor(min / 16);
  const second = Math.floor(Math.random() * 16);
  return first.toString(16) + second.toString(16);
}

export default ChartsHook;
