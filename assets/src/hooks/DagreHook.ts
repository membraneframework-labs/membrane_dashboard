import G6, { G6GraphEvent, GraphData } from "@antv/g6";

import { ViewHookInterface } from "phoenix_live_view";
import {createDagre} from "../utils/dagre";

interface DagreData {
    data: GraphData;
}

interface FocusComboData {
  id: string;
}

type Hook = ViewHookInterface & {graph: G6.Graph};

const DagreHook = {
    mounted(this: Hook) {
        const width = this.el.scrollWidth - 20;
        const height = this.el.scrollHeight;
        
        const graph = createDagre(this.el, width, height);
        window.onresize = () => {
          if (!graph || graph.get('destroyed')) return;
          if (!this.el || !this.el.scrollWidth || !this.el.scrollHeight) return;
          console.log(this.el.scrollWidth, this.el.scrollHeight);
          this.graph.changeSize(this.el.scrollWidth, this.el.scrollHeight);
        };
        this.graph = graph;
        
        
        document.getElementById("dagre-relayout")?.addEventListener("click", () => {
          this.graph.updateLayout({sortByCombo: true})
          console.log(this.graph);
        });

        // this looks nasty...
        (document.querySelector("#dagre-container > canvas")! as HTMLCanvasElement).onselectstart = function () { return false;}

        this.handleEvent("dagre_data", (payload) => {
            const data = (payload as DagreData).data;
            
            const topLevelCombos = data.combos?.filter((combo) => !combo.parentId) || [];
            
            this.pushEvent("top-level-combos", topLevelCombos);

            this.graph.data(data);
            this.graph.render();
            this.graph.changeSize(this.el.scrollWidth, this.el.scrollHeight);
        });
        
        this.handleEvent("focus_combo", (payload) => {
          this.graph.focusItem((payload as FocusComboData).id);
        });
    }
};

export default DagreHook;