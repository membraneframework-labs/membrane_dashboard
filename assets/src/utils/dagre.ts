import { Graph, ComboConfig } from "@antv/g6";

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
    layout: {
      type: "dagre",
      rankdir: "LR",
      sortByCombo: true,
      ranksep: 10,
      nodesep: 10,
    },
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

export function getTopLevelCombos(
  combos: ComboConfig[] | undefined
): ComboConfig[] {
  return combos?.filter((combo) => !combo.parentId) || [];
}

export function comboIdChanged(
  oldCombos: ComboConfig[],
  newCombos: ComboConfig[]
): boolean {
  if (oldCombos.length !== newCombos.length) return true;

  const oldIdSet = new Set(oldCombos.map((combo) => combo.id));
  for (const combo of newCombos) {
    if (!oldIdSet.has(combo.id)) return true;
  }

  return false;
}
