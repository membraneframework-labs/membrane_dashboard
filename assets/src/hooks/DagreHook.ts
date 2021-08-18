import { Graph, GraphData } from "@antv/g6";

import { ViewHookInterface } from "phoenix_live_view";
import { areNodesDifferent, createDagre, defaultLayout, graphInteractionListener } from "../utils/dagre";

interface DagreData {
  data: GraphData;
}

interface FocusComboData {
  id: string;
}

type Hook = ViewHookInterface & { graph: Graph } & { hasUserInteractedSinceLastRender: boolean };

const DagreHook = {
  mounted(this: Hook) {
    const width = this.el.scrollWidth - 20;
    const height = this.el.scrollHeight;

    const graph = createDagre(this.el, width, height);
    this.graph = graph;

    this.hasUserInteractedSinceLastRender = false;

    window.onresize = () => {
      if (!graph || graph.get("destroyed")) return;
      if (!this.el || !this.el.scrollWidth || !this.el.scrollHeight) return;
      this.graph.changeSize(this.el.scrollWidth, this.el.scrollHeight);
    };

    document.getElementById("dagre-relayout")?.addEventListener("click", () => {
      this.graph.updateLayout(defaultLayout);
      if (this.hasUserInteractedSinceLastRender) {
        this.graph.destroyLayout();
      }
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

    const dagreRenderBtn = document.getElementById("dagre-render");
    dagreRenderBtn?.addEventListener("click", () => {
      dagreRenderBtn?.style.setProperty("display", "");
      renderGraph();
    });

    const listenForUserInteractions = () => {
      this.hasUserInteractedSinceLastRender = false;
      this.graph.updateLayout(defaultLayout);

      const listen = graphInteractionListener(this.graph, () => {
        this.hasUserInteractedSinceLastRender = true;
        this.graph.destroyLayout();
      });

      listen();
    };

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

      const previousNodes = (this.graph.save() as GraphData).nodes || [];
      const newNodes = data.nodes || [];

      if (previousNodes.length === 0) {
        this.graph.data(data);
        renderGraph();
        return;
      }

      const nodesDifferent = areNodesDifferent(previousNodes, newNodes);

      if (nodesDifferent) {
        this.graph.data(data);
        if (this.hasUserInteractedSinceLastRender) {
          // the user has interacted with the graph, let them render manually later
          dagreRenderBtn?.style.setProperty("display", "block");
        } else {
          renderGraph();
        }
      } else {
        // no new/removed nodes, make diff and update state of the present elements
        this.graph.changeData(data);
      }
    });

    this.handleEvent("focus_combo", (payload) => {
      this.graph.focusItem((payload as FocusComboData).id, true);
    });

    const renderGraph = () => {
      this.graph.render();
      this.graph.changeSize(this.el.scrollWidth, this.el.scrollHeight);
      listenForUserInteractions();
    };
  },
};

export default DagreHook;
