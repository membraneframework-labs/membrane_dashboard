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
  isAltDown: boolean;
  isMouseOverDiagram: boolean;
  controls: HTMLElement;
  graph: Graph;
  isInPreviewMode: () => boolean;
};

const DagreHook = {
  mounted(this: Hook) {
    const width = this.el.scrollWidth - 20;
    const height = this.el.scrollHeight;

    this.isAltDown = false;
    this.isMouseOverDiagram = false;
    this.controls = document.getElementById("dagre-controls")!;

    const graph = createDagre(this.el, width, height);
    this.graph = graph;

    window.onresize = () => {
      if (!graph || graph.get("destroyed")) return; // eslint-disable-next-line
      if (!this.el || !this.el.scrollWidth || !this.el.scrollHeight) return;

      this.graph.changeSize(this.el.scrollWidth, this.el.scrollHeight);
    };

    // -------------------- //
    // FOCUS MODE LISTENERS //
    // -------------------- //

    // Attach listeners to allow for focusing certain pipelines/bins/elements
    // so that other parts of the dashboard can display limited information.
    // The shortcut to focus certain element is to press 'Alt' + 'Mouse click'.
    for (const eventType of ["node:click", "combo:click"]) {
      this.graph.on(eventType, (e) => {
        // This a AntV G6 custom event wrapping the browser's event while adding some metadata.
        // What we are interested in is a propagation path which carries information about all
        // consecutive elements, starting from root, down to the clicked element itself.
        // The first element from the path is irrelevant as it is the text element visible in the dagre,
        // so we are interested in the second element  carrying the actual element.
        if ((e.originalEvent as MouseEvent).altKey) {
          // ignore the fist element and catch the second element which is a group
          // eslint-disable-next-line
          const [_, group] = e.propagationPath;

          this.pushEvent("dagre:focus:path", {
            // this may look ugly but this is the path to access element's metadata
            // that carries the 'path' field consisting of actual path understood
            // by backend
            path: group.cfg.item._cfg.model.path,
          });
        }
      });
    }

    const checkDiagramFocusMode = () => {
      if (this.isAltDown && this.isMouseOverDiagram) {
        document
          .getElementById("dagre-diagram")!
          .classList.add("Dagre-focusMode");
      } else {
        document
          .getElementById("dagre-diagram")!
          .classList.remove("Dagre-focusMode");
      }
    };

    this.el.addEventListener("mouseenter", () => {
      this.isMouseOverDiagram = true;
      checkDiagramFocusMode();
    });

    this.el.addEventListener("mouseleave", () => {
      this.isMouseOverDiagram = false;
      checkDiagramFocusMode();
    });

    window.addEventListener("keydown", (e) => {
      if (e.key === "Alt") {
        this.isAltDown = true;
        checkDiagramFocusMode();
      }
    });

    window.addEventListener("keyup", (e) => {
      if (e.key === "Alt") {
        this.isAltDown = false;
        checkDiagramFocusMode();
      }
    });

    // ------------------ //
    // CONTROLS LISTENERS //
    // ------------------ //

    // setting preview mode
    this.isInPreviewMode = () => this.graph.getCurrentMode() === "preview";
    this.graph.setMode("preview");

    const canvas = this.el.querySelector<HTMLCanvasElement>("canvas")!;
    // disable double click from selecting text outside of canvas
    canvas.onselectstart = function () {
      return false;
    };

    maybeAddEventListener(this.controls, "click", "dagre-mode", () => {
      const [newMode, innerText] = this.isInPreviewMode()
        ? ["snapshot", "Exit snapshot mode"]
        : ["preview", "Snapshot mode"];

      this.graph.setMode(newMode);

      const dagreModeBtn = this.controls.querySelector<HTMLElement>(
        dataId("dagre-mode")
      )!;
      dagreModeBtn.innerText = innerText;
    });

    maybeAddEventListener(this.controls, "click", "dagre-fit-view", () => {
      this.graph.fitView();
    });

    maybeAddEventListener(this.controls, "click", "dagre-relayout", () => {
      this.graph.layout();
    });

    maybeAddEventListener(this.controls, "click", "dagre-clear", () => {
      this.graph.clear();
    });

    maybeAddEventListener(this.controls, "click", "dagre-export-image", () => {
      const oldRatio = this.graph.getZoom();
      // this zoom is needed to make sure downloaded image is sharp
      this.graph.zoomTo(1.0);
      this.graph.downloadFullImage("pipelines-graph", "image/png", {
        padding: [30, 15, 15, 15],
      });
      this.graph.zoomTo(oldRatio);
    });

    // --------------- //
    // GRAPH LISTENERS //
    // --------------- //

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

    // ------------------ //
    // LV EVENT LISTENERS //
    // ------------------ //

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

// some node names can get really long even though they can come with line breaks
// allow for up to 60 character lines and show `...` if the line exceeds the limit
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

function dataId(id: string) {
  return `[data-id='${id}']`;
}

function maybeAddEventListener(
  element: HTMLElement,
  event: string,
  id: string,
  cb: () => void
) {
  element.querySelector(dataId(id))?.addEventListener(event, cb);
}

export default DagreHook;
