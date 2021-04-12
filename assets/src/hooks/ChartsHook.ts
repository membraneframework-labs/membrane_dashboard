import uPlot, { AlignedData, Series } from "uPlot"

import { ViewHookInterface } from "phoenix_live_view";
import {createCharts} from "../utils/charts";

type Hook = ViewHookInterface & {chart_store: uPlot, chart_take_and_demand: uPlot};

interface ChartsData {
    series: Series[];
    data: AlignedData;
}

interface IncomingData {
    data: ChartsData;
}

const ChartsHook = {
    mounted(this: Hook) {
        console.log("Mounting dagre");
        const width = this.el.scrollWidth - 20;
        const height = this.el.scrollHeight;
        
        const chart = createCharts(this.el, width, height);
        this.chart_store = chart

        // this.chart_take_and_demand = createCharts(this.el, width, height);

        this.handleEvent("charts_data", (payload) => {
            console.log("Received charts data");
            const chartsData = (payload as IncomingData).data;

            while (this.chart_store.series.length > 1) {
                this.chart_store.delSeries(1);
            }
            this.chart_store.delSeries(0);

            chartsData.series[0].value = (self, rawValue) => {
                let data = new Date(rawValue * 1000);
                return uPlot.fmtDate('{YYYY}-{MM}-{DD} {H}:{mm}:{ss}')(data);
            }

            for (let series of chartsData.series) {
                let color = randomColor();
                series.stroke = color;
                series.paths = u => null;
                series.points = {
                    space: 0,
                    fill: color,
                };
                this.chart_store.addSeries(series);
            }

            this.chart_store.setData(chartsData.data);
        })
    }
};

function randomColor() {
    return "#" + randomHexNumber(64, 255) + randomHexNumber(64, 255) + randomHexNumber(64, 255);
}

function randomHexNumber(min: number, max: number) {
    let first = Math.floor(Math.random() * (Math.floor(max / 16) - Math.floor(min / 16))) + Math.floor(min / 16);
    let second = Math.floor(Math.random() * 16);
    return first.toString(16) + second.toString(16);
}

export default ChartsHook;