import { ComboConfig, Graph, GraphData } from "@antv/g6";

import { ViewHookInterface } from "phoenix_live_view";
import { createDagre, getTopLevelCombos, comboIdChanged } from "../utils/dagre";

interface DagreData {
  data: GraphData;
}

interface FocusComboData {
  id: string;
}

type Hook = ViewHookInterface & { graph: Graph };

const DagreHook = {
  mounted(this: Hook) {
    const width = this.el.scrollWidth - 20;
    const height = this.el.scrollHeight;
    let canRerenderPipelines = true;

    const graph = createDagre(this.el, width, height);
    this.graph = graph;

    window.onresize = () => {
      if (!graph || graph.get("destroyed")) return;
      if (!this.el || !this.el.scrollWidth || !this.el.scrollHeight) return;
      this.graph.changeSize(this.el.scrollWidth, this.el.scrollHeight);
    };

    document.getElementById("dagre-relayout")?.addEventListener("click", () => {
      this.graph.updateLayout({ sortByCombo: true });
    });

    document.getElementById("dagre-export-image")?.addEventListener("click", () => {
      const oldRatio = this.graph.getZoom();
      // this zoom is needed to make sure downloaded image is sharp
      this.graph.zoomTo(1.0);
      this.graph.downloadFullImage("pipelines-graph", "image/png", {
        padding: [30, 15, 15, 15],
      });
      this.graph.zoomTo(oldRatio);
    });

    const dagreRerenderBtn = document.getElementById("dagre-rerender");
    dagreRerenderBtn?.addEventListener("click", () => {
      renderPipelines();
    });

    const canvas = document.querySelector(
      "#dagre-container > canvas"
    )! as HTMLCanvasElement;
    // disable double click from selecting text outside of canvas
    canvas.onselectstart = function () {
      return false;
    };
    const canvasClickListener = () => {
      canRerenderPipelines = false;
      canvas.removeEventListener("click", canvasClickListener);
    };
    canvas.addEventListener("click", canvasClickListener);

    this.handleEvent("dagre_data", (payload) => {
      const data = (payload as DagreData).data;

      const oldCombos = this.graph.save().combos as ComboConfig[] || [];
      const newCombos = data.combos || [];

      const topLevelCombos = getTopLevelCombos(newCombos);
      this.pushEvent("top-level-combos", topLevelCombos);

      this.graph.data(data);

      if (canRerenderPipelines || oldCombos.length === 0) {
        // canvas has not been touched or is empty, just render new pipelines
        renderPipelines();
      } else if (comboIdChanged(oldCombos, newCombos)) {
        // new pipelines, but canvas not empty - display a button to rerender manually
        dagreRerenderBtn?.style.setProperty("display", "block");
      } else {
        // no new pipelines, refresh the current state
        this.graph.refresh();
      }
    });

    this.handleEvent("focus_combo", (payload) => {
      this.graph.focusItem((payload as FocusComboData).id, true);
    });

    const renderPipelines = () => {
      dagreRerenderBtn?.style.setProperty("display", "");
      this.graph.render();
      this.graph.changeSize(this.el.scrollWidth, this.el.scrollHeight);
      canRerenderPipelines = true;
      canvas.addEventListener("click", canvasClickListener);
    };
  },
};

export default DagreHook;
