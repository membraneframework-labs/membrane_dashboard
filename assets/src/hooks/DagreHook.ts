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
  dagrePlaceholder: HTMLElement;
  graph: Graph;
  isInPreviewMode: () => boolean;
};

const DagreHook = {
  mounted(this: Hook) {
    this.dagrePlaceholder = this.el.querySelector(dataId("dagre-placeholder"))!;
    const width = this.dagrePlaceholder.scrollWidth - 20;
    const height = this.dagrePlaceholder.scrollHeight;

    const graph = createDagre(this.dagrePlaceholder, width, height);
    this.graph = graph;

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

    this.isInPreviewMode = () => this.graph.getCurrentMode() === "preview";
    this.graph.setMode("preview");

    window.onresize = () => {
      if (!graph || graph.get("destroyed")) return;
      // eslint-disable-next-line
      if (
        !this.dagrePlaceholder ||
        !this.dagrePlaceholder.scrollWidth ||
        !this.dagrePlaceholder.scrollHeight
      )
        return;

      this.graph.changeSize(
        this.dagrePlaceholder.scrollWidth,
        this.dagrePlaceholder.scrollHeight
      );
    };

    const canvas = this.el.querySelector<HTMLCanvasElement>("canvas")!;
    // disable double click from selecting text outside of canvas
    canvas.onselectstart = function () {
      return false;
    };

    maybeAddEventListener(this.el, "click", "dagre-mode", () => {
      const [newMode, innerText] = this.isInPreviewMode()
        ? ["snapshot", "Exit snapshot mode"]
        : ["preview", "Snapshot mode"];

      this.graph.setMode(newMode);

      const dagreModeBtn = this.el.querySelector<HTMLElement>(
        dataId("dagre-mode")
      )!;
      dagreModeBtn.innerText = innerText;
    });

    maybeAddEventListener(this.el, "click", "dagre-fit-view", () => {
      this.graph.fitView();
    });

    maybeAddEventListener(this.el, "click", "dagre-relayout", () => {
      this.graph.layout();
    });

    maybeAddEventListener(this.el, "click", "dagre-clear", () => {
      this.graph.clear();
    });

    maybeAddEventListener(this.el, "click", "dagre-export-image", () => {
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
      this.graph.changeSize(
        this.dagrePlaceholder.scrollWidth,
        this.dagrePlaceholder.scrollHeight
      );
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
