import uPlot, { AlignedData, Series } from "uPlot";

import { ViewHookInterface } from "phoenix_live_view";
import { createCharts } from "../utils/charts";

type Hook = ViewHookInterface & {
  charts: uPlot[];
  data: AlignedData[];
};

interface InitData {
  data: string[];
}

interface ChartData {
  series: Series[];
  data: AlignedData;
}

interface RefreshData {
  data: ChartData[];
}

const ChartsHook = {
  mounted(this: Hook) {
    this.charts = [];

    // creating empty charts with proper names and sizes
    this.handleEvent("charts_init", (payload) => {
      const width = this.el.scrollWidth - 20;
      const methods = (payload as InitData).data;
      for (const method of methods) {
        const chart = createCharts(this.el, width, method);
        this.charts.push(chart);
      }
    });

    // full charts update
    this.handleEvent("charts_data", (payload) => {
      const chartsData = (payload as RefreshData).data;

      for (let i = 0; i < chartsData.length; i++) {
        // new series can be different from old ones, so all old series should be deleted
        for (let j = this.charts[i].series.length - 1; j >= 0; j--) {
          this.charts[i].delSeries(j);
        }

        // x axis ticks are given in seconds, but for the plot they need to be in milliseconds, so 'rawValue'
        // is multiplied by 1000
        const formatter = uPlot.fmtDate("{YYYY}-{MM}-{DD} {H}:{mm}:{ss}");
        chartsData[i].series[0].value = (_, rawValue) => {
          return formatter(new Date(rawValue * 1000));
        };

        // configures series and adds them to the chart
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

    // live update patch
    this.handleEvent("charts_update", (payload) => {
      const chartsData = (payload as RefreshData).data;

      for (let i = 0; i < chartsData.length; i++) {
        // configures new series and adds them to the chart
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
  const [a, b, c] = ["", "", ""].map((_) => randomHexNumber(64, 255));
  return `#${a}${b}${c}`;
}

function randomHexNumber(min: number, max: number): string {
  const first =
    Math.floor(Math.random() * (Math.floor(max / 16) - Math.floor(min / 16))) +
    Math.floor(min / 16);
  const second = Math.floor(Math.random() * 16);
  return first.toString(16) + second.toString(16);
}

export default ChartsHook;
