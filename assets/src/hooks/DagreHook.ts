import { Graph, GraphData } from "@antv/g6";

import { ViewHookInterface } from "phoenix_live_view";
import { createDagre } from "../utils/dagre";

interface DagreData {
  data: GraphData;
}

interface FocusComboData {
  id: string;
}

type Hook = ViewHookInterface & {
  graph: Graph;
  isInPreviewMode: () => boolean;
};

function reformatNodeNames(data: GraphData) {
  const nodes = (data.nodes ?? []).map((node) => {
    const label: string = (node.label as string) || "";

    const newLabel = label
      .split("\n")
      .map((part) => (part.length < 60 ? part : part.slice(0, 60) + "..."))
      .join("\n");

    return { ...node, label: newLabel };
  });

  return { ...data, nodes };
}

const DagreHook = {
  mounted(this: Hook) {
    const width = this.el.scrollWidth - 20;
    const height = this.el.scrollHeight;

    const graph = createDagre(this.el, width, height);
    this.graph = graph;

    this.graph.on("node:click", (e) => {
      if ((e.originalEvent as MouseEvent).altKey) {
        const [_, group] = e.propagationPath;

        this.pushEvent("dagre:focus:path", {
          path: group.cfg.item._cfg.model.path,
        });
      }
    });

    this.isInPreviewMode = () => this.graph.getCurrentMode() === "preview";
    this.graph.setMode("preview");

    window.onresize = () => {
      if (!graph || graph.get("destroyed")) return;
      if (!this.el || !this.el.scrollWidth || !this.el.scrollHeight) return;
      this.graph.changeSize(this.el.scrollWidth, this.el.scrollHeight);
    };

    const canvas = document.querySelector(
      "#dagre-container > canvas"
    )! as HTMLCanvasElement;
    // disable double click from selecting text outside of canvas
    canvas.onselectstart = function () {
      return false;
    };

    const dagreModeBtn = document.getElementById("dagre-mode");
    dagreModeBtn?.addEventListener("click", () => {
      const [newMode, innerText] = this.isInPreviewMode()
        ? ["snapshot", "Exit snapshot mode"]
        : ["preview", "Snapshot mode"];

      this.graph.setMode(newMode);
      dagreModeBtn.innerText = innerText;
    });

    document.getElementById("dagre-fit-view")?.addEventListener("click", () => {
      this.graph.fitView();
    });

    document.getElementById("dagre-relayout")?.addEventListener("click", () => {
      this.graph.layout();
    });

    document.getElementById("dagre-clear")?.addEventListener("click", () => {
      this.graph.clear();
    });

    document
      .getElementById("dagre-export-image")
      ?.addEventListener("click", () => {
        const oldRatio = this.graph.getZoom();
        // this zoom is needed to make sure downloaded image is sharp
        this.graph.zoomTo(1.0);
        this.graph.downloadFullImage("pipelines-graph", "image/png", {
          padding: [30, 15, 15, 15],
        });
        this.graph.zoomTo(oldRatio);
      });

    this.graph.on("beforemodechange", ({ mode }) => {
      if (mode === "preview") {
        this.graph.getCombos().forEach((combo) => {
          this.graph.expandCombo(combo);
        });
        this.graph.refreshPositions();
      }
    });

    this.graph.on("afterrender", () => {
      this.graph.changeSize(this.el.scrollWidth, this.el.scrollHeight);
      this.graph.fitView();
    });

    this.handleEvent("dagre:data", (payload) => {
      const data = reformatNodeNames((payload as DagreData).data);

      const topLevelCombos =
        data.combos?.filter((combo) => !combo.parentId) || [];
      this.pushEvent("dagre:top-level-combos", topLevelCombos);

      if (this.graph.getNodes().length === 0) {
        this.graph.read(data);
      } else if (this.isInPreviewMode()) {
        this.graph.changeData(data);
      } else {
        this.graph.data(data);
      }
    });

    this.handleEvent("dagre:focus:combo", (payload) => {
      this.graph.focusItem((payload as FocusComboData).id, true);
    });
  },
};

export default DagreHook;
