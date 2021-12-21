import uPlot, { AlignedData, Series } from "uplot";

import { ViewHookInterface } from "phoenix_live_view";
import { createChart } from "../utils/charts";

type Hook = ViewHookInterface & {
  charts: Record<string, uPlot>;
  data: AlignedData[];
};

interface ChartData {
  series: Series[];
  data: AlignedData;
}

interface RefreshData {
  metric: string;
  data: ChartData;
}

const ChartsHook = {
  destroyed(this: Hook) {
    Object.values(this.charts).forEach((chart) => chart.destroy());
    this.charts = {};
  },
  disconnected(this: Hook) {
    Object.values(this.charts).forEach((chart) => chart.destroy());
    this.charts = {};
  },
  mounted(this: Hook) {
    this.charts = {};

    window.addEventListener("resize", () => {
      const size = getSize();
      Object.values(this.charts).forEach((chart) => {
        chart.setSize({ ...size, height: chart.height });
      });
    });

    // full charts update
    this.handleEvent("charts:full", (payload) => {
      const { metric, data: chartData } = payload as RefreshData;

      let chart;
      if (!(metric in this.charts)) {
        chart = this.charts[metric] = createChart(
          this.el,
          this.el.scrollWidth - 20,
          metric
        );
      } else {
        chart = this.charts[metric];
      }

      for (let i = chart.series.length - 1; i >= 0; i--) {
        chart.delSeries(i);
      }

      // new series can be different from old ones, so all old series should be deleted

      // x axis ticks are given in seconds, but for the plot they need to be in milliseconds, so 'rawValue'
      // is multiplied by 1000
      const formatter = uPlot.fmtDate("{YYYY}-{MM}-{DD} {H}:{mm}:{ss}");
      chartData.series[0].value = (_, rawValue) => {
        return formatter(new Date(rawValue * 1000));
      };

      // configures series and adds them to the chart
      for (const series of chartData.series) {
        const color = randomColor();
        series.stroke = color;
        series.spanGaps = true;
        series.points = {
          width: 1 / window.devicePixelRatio,
        };
        chart.addSeries(series);
      }

      // given series is empty therefore hide the charts
      const chartElement = document.getElementById(chart.root.id);
      if (chart.series.length < 2) {
        chartElement!.style.display = "none";
      } else {
        chartElement!.style.display = "block";
      }

      chart.setData(chartData.data);
    });

    // live update patch
    this.handleEvent("charts:update", (payload) => {
      const { metric, data: chartData } = payload as RefreshData;

      const chart = this.charts[metric];
      console.assert(
        !!chart,
        "Chart should be present during update but is not..."
      );

      for (let i = chart.series.length; i < chartData.series.length; i++) {
        const series = chartData.series[i];
        const color = randomColor();
        series.stroke = color;
        series.spanGaps = true;
        series.points = {
          width: 1 / window.devicePixelRatio,
        };
        chart.addSeries(series);
      }

      // given series is empty therefore hide the charts
      const chartElement = document.getElementById(chart.root.id);
      if (chart.series.length < 2) {
        chartElement!.style.display = "none";
      } else {
        chartElement!.style.display = "block";
      }

      chart.setData(chartData.data);
    });

    this.handleEvent("charts:filter", (payload) => {
      const { seriesPrefix } = payload as { seriesPrefix: string };

      Object.values(this.charts).forEach((chart) => {
        chart.series.forEach((series, idx) => {
          const show =
            series?.label === "time" || series.label?.startsWith(seriesPrefix);
          chart.setSeries(idx, { show });
        });
      });
    });

    this.handleEvent("charts:metrics:selected", (payload) => {
      const { metrics } = payload as { metrics: string[] };

      for (const metricName in this.charts) {
        if (!metrics.includes(metricName)) {
          this.charts[metricName].destroy();
          delete this.charts[metricName];
        }
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

function getSize() {
  return {
    width: window.innerWidth - 100,
    height: window.innerHeight - 200,
  };
}

export default ChartsHook;
