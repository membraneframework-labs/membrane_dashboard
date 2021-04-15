import uPlot, { AlignedData } from "uPlot";

export function createCharts(
  container: HTMLElement,
  width: number,
  height: number
): uPlot {
  const data: AlignedData = [[]];

  return new uPlot(
    {
      width: width,
      height: 200,

      title: "Input buffer size inside store/3",

      id: "chart1",

      class: "my-chart",

      series: [],

      axes: [
        {
          values: [
            // tick incr  default       year                        month   day                  hour   min               sec  mode 
            [3600*24*365,"{YYYY}",      null,                       null, null,                  null, null,              null, 1],
            [3600*24*28, "{MMM}",       "\n{YYYY}",                 null, null,                  null, null,              null, 1],
            [3600*24,    "{D}/{M}",     "\n{YYYY}",                 null, null,                  null, null,              null, 1],
            [3600,       "{HH}",        "\n{D}/{M}/{YY}",           null, "\n{D}/{M}",           null, null,              null, 1],
            [60,         "{HH}:{mm}",   "\n{D}/{M}/{YY}",           null, "\n{D}/{M}",           null, null,              null, 1],
            [1,          ":{ss}",       "\n{D}/{M}/{YY} {HH}:{mm}", null, "\n{D}/{M} {HH}:{mm}", null, "\n{HH}:{mm}",     null, 1],
            [0.001,      ":{ss}.{fff}", "\n{D}/{M}/{YY} {HH}:{mm}", null, "\n{D}/{M} {HH}:{mm}", null, "\n{HH}:{mm}",     null, 1],
          ],
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
