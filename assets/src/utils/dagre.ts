import { Graph, NodeConfig } from "@antv/g6";

export const defaultLayout = {
  type: "dagre",
  rankdir: "LR",
  sortByCombo: true,
  ranksep: 10,
  nodesep: 10,
};

export function createDagre(
  container: HTMLElement,
  width: number,
  height: number
): Graph {
  return new Graph({
    container: container.id,
    width,
    height,
    fitView: true,
    fitViewPadding: 30,
    animate: true,
    groupByTypes: false,
    enabledStack: false,
    modes: {
      default: [
        "drag-combo",
        "drag-node",
        "drag-canvas",
        "zoom-canvas",
        {
          type: "collapse-expand-combo",
          relayout: false,
        },
      ],
    },
    layout: defaultLayout,
    defaultNode: {
      size: [400, 50],
      type: "rect",
      style: {
        radius: 10,
        stroke: "white",
      },
      anchorPoints: [
        [0, 0.5],
        [1, 0.5],
      ],
    },
    defaultEdge: {
      type: "line",
      size: 2,
      color: "#e2e2e2",
      style: {
        endArrow: {
          path: "M 0,0 L 8,4 L 8,-4 Z",
          fill: "#e2e2e2",
        },
        radius: 20,
      },
    },
    defaultCombo: {
      type: "rect",
      size: [300, 50],

      style: {
        fillOpacity: 0.1,
        textAlign: "center",
        fill: "#fff4b5",
      },
    },
  });
}

const graphInteractionEvents = ["click", "dragstart", "touchstart"];

export function graphInteractionListener(
  graph: Graph,
  handler: () => void
): () => void {
  return function() {
    graphInteractionEvents.forEach((event) => graph.on(event, () => {
      handler();
      graphInteractionEvents.forEach((event) => graph.off(event));
    }));
  };
}

export function nodeIdsDifferent(
  nodes1: NodeConfig[],
  nodes2: NodeConfig[]
): boolean {
  if (nodes1.length !== nodes2.length) return true;

  const [bigger, smaller] =
    nodes1.length > nodes2.length
      ? [nodes1, nodes2]
      : [nodes2, nodes1];

  const idSet = new Set(bigger.map((node) => node.id));
  for (const node of smaller) {
    if (!idSet.has(node.id)) return true;
  }

  return false;
}
