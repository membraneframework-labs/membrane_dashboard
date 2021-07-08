import { Graph, GraphData } from "@antv/g6";

import { ViewHookInterface } from "phoenix_live_view";
import { createDagre } from "../utils/dagre";

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
      this.graph.downloadFullImage("pipelines-graph", "image/png", {
        padding: [30, 15, 15, 15],
      });
      this.graph.updateLayout({ sortByCombo: true });
    });

    const canvas = document.querySelector(
      "#dagre-container > canvas"
    )! as HTMLCanvasElement;
    // disable double click from selecting text outside of canvas
    canvas.onselectstart = function () {
      return false;
    };

    this.handleEvent("dagre_data", (payload) => {
      const data = (payload as DagreData).data;

      const topLevelCombos =
        data.combos?.filter((combo) => !combo.parentId) || [];
      this.pushEvent("top-level-combos", topLevelCombos);

      this.graph.data(data);

      this.graph.render();

      this.graph.changeSize(this.el.scrollWidth, this.el.scrollHeight);
    });

    this.handleEvent("focus_combo", (payload) => {
      this.graph.focusItem((payload as FocusComboData).id, true);
    });
  },
};

export default DagreHook;
