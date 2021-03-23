import G6, { GraphData } from "@antv/g6";

import { ViewHookInterface } from "phoenix_live_view";

interface DagreData {
    data: GraphData;
}

const DagreHook = {
    mounted(this: ViewHookInterface) {
        this.handleEvent("dagre_data", (payload) => {
            console.log("Received data");
            
            
            const data = (payload as DagreData).data;
            // const data = { "combos": [ { "id": "2C33255418F22B0B2F6FB9D22E9590CC", "label": ":rtp bin", "parentId": "84362AA45BEF67904DC3C1B9ADEC0623" }, { "id": "4C6D4A78089FA76B8B8E7395FF109101", "label": ":ice bin", "parentId": "84362AA45BEF67904DC3C1B9ADEC0623" }, { "id": "68DF962F6665ED377BA2E6F512917BE9", "label": "pipeline@<0.590.0>", "parentId": null }, { "id": "737480B4FCAAF8447DAB87A3EEE137BD", "label": "{:stream_receive_bin, 3045221371} bin", "parentId": "2C33255418F22B0B2F6FB9D22E9590CC" }, { "id": "84362AA45BEF67904DC3C1B9ADEC0623", "label": "{:endpoint, #PID<0.589.0>} bin", "parentId": "68DF962F6665ED377BA2E6F512917BE9" }, { "id": "E5DEA8DE1A2D8DE8A7CF4E086A3BF7A9", "label": "{:stream_receive_bin, 1730358992} bin", "parentId": "2C33255418F22B0B2F6FB9D22E9590CC" } ], "edges": [ { "source": "032779EDCA1A11470CB54143D1753AFA", "target": "F931C15132D21F66A5C96CCDB6B20308" }, { "source": "139C2A6D1FD75FDBB164A45F565F6208", "target": "6E7C90E25A14836FF03C02EFB2E488CF" }, { "source": "1641A750767498F7FE465D6417D1AAAF", "target": "C500664917F734508B358F8BD89D3CEF" }, { "source": "182AB1FB6C32EBB1E5A5434121F9C1FD", "target": "2D30270D6AF2BD50C53C6BF8FB6B8D23" }, { "source": "18893531781A7A98A9A5DF1777A1B596", "target": "8BC7302494277B256CBAB26AB81475F1" }, { "source": "289D8EBC3C80D467C178DF46210BF244", "target": "18893531781A7A98A9A5DF1777A1B596" }, { "source": "29D061DCF54F599E3D74BA9C0E6D480D", "target": "5E5DA9FDE67D0282D28D4387475F8A62" }, { "source": "51F744DCDE05D424615132DBF76C3AD1", "target": "139C2A6D1FD75FDBB164A45F565F6208" }, { "source": "51F744DCDE05D424615132DBF76C3AD1", "target": "75B063953EF3B4DC029E5DF65FD3D248" }, { "source": "5E5DA9FDE67D0282D28D4387475F8A62", "target": "51F744DCDE05D424615132DBF76C3AD1" }, { "source": "6428CE79B929E5BA5A9D31D589A6DD45", "target": "85A46F32B1AC0F88F7676874B20FDF8A" }, { "source": "676F90847F15D8ED720421BE98D2DC71", "target": "F947619282FC801073D1461CC62D9C07" }, { "source": "6E7C90E25A14836FF03C02EFB2E488CF", "target": "AD5234EB25B9EF39F8D4657C2D485ECB" }, { "source": "75B063953EF3B4DC029E5DF65FD3D248", "target": "960129C2C8819A332219169AB242EF32" }, { "source": "75B063953EF3B4DC029E5DF65FD3D248", "target": "A111C6197D6673972BF6CAE39919AEEE" }, { "source": "85A46F32B1AC0F88F7676874B20FDF8A", "target": "29D061DCF54F599E3D74BA9C0E6D480D" }, { "source": "8BC7302494277B256CBAB26AB81475F1", "target": "BEAF9094AE732586861C1FBF4DBA9B9E" }, { "source": "91D27CF28F0C1B5652075F5A8CB32A31", "target": "676F90847F15D8ED720421BE98D2DC71" }, { "source": "960129C2C8819A332219169AB242EF32", "target": "032779EDCA1A11470CB54143D1753AFA" }, { "source": "A111C6197D6673972BF6CAE39919AEEE", "target": "D5943543D919E07EC7D95ADDEF2496D6" }, { "source": "AD5234EB25B9EF39F8D4657C2D485ECB", "target": "182AB1FB6C32EBB1E5A5434121F9C1FD" }, { "source": "BEAF9094AE732586861C1FBF4DBA9B9E", "target": "1641A750767498F7FE465D6417D1AAAF" }, { "source": "C5D9373F5F5C2FF8E2A61A9D24B64F90", "target": "B27249FD032B950DC4F44DBE8F3B0FD6" }, { "source": "CC879BDF9E3BBCBDD58D4A05A6064C8E", "target": "C5D9373F5F5C2FF8E2A61A9D24B64F90" }, { "source": "D19940A754AFE45F599CF2BD955F0614", "target": "CC879BDF9E3BBCBDD58D4A05A6064C8E" }, { "source": "D5943543D919E07EC7D95ADDEF2496D6", "target": "91D27CF28F0C1B5652075F5A8CB32A31" }, { "source": "F931C15132D21F66A5C96CCDB6B20308", "target": "289D8EBC3C80D467C178DF46210BF244" }, { "source": "F947619282FC801073D1461CC62D9C07", "target": "D19940A754AFE45F599CF2BD955F0614" } ], "nodes": [ { "comboId": "2C33255418F22B0B2F6FB9D22E9590CC", "id": "139C2A6D1FD75FDBB164A45F565F6208", "label": "{:srtcp_encryptor, #Reference<0.1591590362.3824156676.126950>}", "style": {} }, { "comboId": "2C33255418F22B0B2F6FB9D22E9590CC", "id": "29D061DCF54F599E3D74BA9C0E6D480D", "label": ":rtp\n{Membrane.Pad, :rtp_input, #Reference<0.1591590362.3824156676.126950>}", "style": { "fill": "#ebb434" } }, { "comboId": "2C33255418F22B0B2F6FB9D22E9590CC", "id": "51F744DCDE05D424615132DBF76C3AD1", "label": "{:rtp_parser, #Reference<0.1591590362.3824156676.126950>}", "style": {} }, { "comboId": "2C33255418F22B0B2F6FB9D22E9590CC", "id": "5E5DA9FDE67D0282D28D4387475F8A62", "label": "{:srtp_decryptor, #Reference<0.1591590362.3824156676.126950>}", "style": {} }, { "comboId": "2C33255418F22B0B2F6FB9D22E9590CC", "id": "6E7C90E25A14836FF03C02EFB2E488CF", "label": ":rtp\n{Membrane.Pad, :rtcp_output, #Reference<0.1591590362.3824156676.126950>}", "style": { "fill": "#ebb434" } }, { "comboId": "2C33255418F22B0B2F6FB9D22E9590CC", "id": "75B063953EF3B4DC029E5DF65FD3D248", "label": ":ssrc_router", "style": {} }, { "comboId": "2C33255418F22B0B2F6FB9D22E9590CC", "id": "8BC7302494277B256CBAB26AB81475F1", "label": ":rtp\n{Membrane.Pad, :output, 3045221371}", "style": { "fill": "#ebb434" } }, { "comboId": "2C33255418F22B0B2F6FB9D22E9590CC", "id": "D19940A754AFE45F599CF2BD955F0614", "label": ":rtp\n{Membrane.Pad, :output, 1730358992}", "style": { "fill": "#ebb434" } }, { "comboId": "4C6D4A78089FA76B8B8E7395FF109101", "id": "182AB1FB6C32EBB1E5A5434121F9C1FD", "label": ":ice\n{Membrane.Pad, :input, 1}", "style": { "fill": "#ebb434" } }, { "comboId": "4C6D4A78089FA76B8B8E7395FF109101", "id": "2D30270D6AF2BD50C53C6BF8FB6B8D23", "label": ":ice_sink", "style": {} }, { "comboId": "4C6D4A78089FA76B8B8E7395FF109101", "id": "6428CE79B929E5BA5A9D31D589A6DD45", "label": ":ice_source", "style": {} }, { "comboId": "4C6D4A78089FA76B8B8E7395FF109101", "id": "85A46F32B1AC0F88F7676874B20FDF8A", "label": ":ice\n{Membrane.Pad, :output, 1}", "style": { "fill": "#ebb434" } }, { "comboId": "68DF962F6665ED377BA2E6F512917BE9", "id": "1641A750767498F7FE465D6417D1AAAF", "label": "{:tee, \"9A19F14F19BC6747\"}", "style": {} }, { "comboId": "68DF962F6665ED377BA2E6F512917BE9", "id": "B27249FD032B950DC4F44DBE8F3B0FD6", "label": "{:fake, \"DF6828D27CBA7559\"}", "style": {} }, { "comboId": "68DF962F6665ED377BA2E6F512917BE9", "id": "C500664917F734508B358F8BD89D3CEF", "label": "{:fake, \"9A19F14F19BC6747\"}", "style": {} }, { "comboId": "68DF962F6665ED377BA2E6F512917BE9", "id": "C5D9373F5F5C2FF8E2A61A9D24B64F90", "label": "{:tee, \"DF6828D27CBA7559\"}", "style": {} }, { "comboId": "737480B4FCAAF8447DAB87A3EEE137BD", "id": "032779EDCA1A11470CB54143D1753AFA", "label": ":rtcp_receiver", "style": {} }, { "comboId": "737480B4FCAAF8447DAB87A3EEE137BD", "id": "18893531781A7A98A9A5DF1777A1B596", "label": "{:stream_receive_bin, 3045221371}\n:output", "style": { "fill": "#ebb434" } }, { "comboId": "737480B4FCAAF8447DAB87A3EEE137BD", "id": "289D8EBC3C80D467C178DF46210BF244", "label": ":depayloader", "style": {} }, { "comboId": "737480B4FCAAF8447DAB87A3EEE137BD", "id": "960129C2C8819A332219169AB242EF32", "label": "{:stream_receive_bin, 3045221371}\n:input", "style": { "fill": "#ebb434" } }, { "comboId": "737480B4FCAAF8447DAB87A3EEE137BD", "id": "F931C15132D21F66A5C96CCDB6B20308", "label": ":jitter_buffer", "style": {} }, { "comboId": "84362AA45BEF67904DC3C1B9ADEC0623", "id": "AD5234EB25B9EF39F8D4657C2D485ECB", "label": ":ice_funnel", "style": {} }, { "comboId": "84362AA45BEF67904DC3C1B9ADEC0623", "id": "BEAF9094AE732586861C1FBF4DBA9B9E", "label": "{:endpoint, #PID<0.589.0>}\n{Membrane.Pad, :output, \"9A19F14F19BC6747\"}", "style": { "fill": "#ebb434" } }, { "comboId": "84362AA45BEF67904DC3C1B9ADEC0623", "id": "CC879BDF9E3BBCBDD58D4A05A6064C8E", "label": "{:endpoint, #PID<0.589.0>}\n{Membrane.Pad, :output, \"DF6828D27CBA7559\"}", "style": { "fill": "#ebb434" } }, { "comboId": "E5DEA8DE1A2D8DE8A7CF4E086A3BF7A9", "id": "676F90847F15D8ED720421BE98D2DC71", "label": ":depayloader", "style": {} }, { "comboId": "E5DEA8DE1A2D8DE8A7CF4E086A3BF7A9", "id": "91D27CF28F0C1B5652075F5A8CB32A31", "label": ":jitter_buffer", "style": {} }, { "comboId": "E5DEA8DE1A2D8DE8A7CF4E086A3BF7A9", "id": "A111C6197D6673972BF6CAE39919AEEE", "label": "{:stream_receive_bin, 1730358992}\n:input", "style": { "fill": "#ebb434" } }, { "comboId": "E5DEA8DE1A2D8DE8A7CF4E086A3BF7A9", "id": "D5943543D919E07EC7D95ADDEF2496D6", "label": ":rtcp_receiver", "style": {} }, { "comboId": "E5DEA8DE1A2D8DE8A7CF4E086A3BF7A9", "id": "F947619282FC801073D1461CC62D9C07", "label": "{:stream_receive_bin, 1730358992}\n:output", "style": { "fill": "#ebb434" } } ] };

            const width = this.el.scrollWidth;
            const height = (this.el.scrollHeight || 500) - 30;
            const graph = new G6.Graph({
              container: this.el, 
              width,
              height: height - 50,

              fitView: true,
              fitViewPadding: 30,
              animate: true,
              groupByTypes: false,
              modes: {
                default: [
                  'drag-combo',
                  'drag-node',
                  'drag-canvas',
                  'zoom-canvas',
                  {
                    type: 'collapse-expand-combo',
                    relayout: false,
                  },
                ],
              },
              layout: {
                type: 'dagre',
                rankdir: "LR",
                sortByCombo: true,
                ranksep: 10,
                nodesep: 10,
              },
              defaultNode: {
                size: [400, 50],
                type: 'rect',
                style: {
                  radius: 10,
                },
                anchorPoints: [
                  //[0.5, 0],
                  //[0.5, 1],
                  [0, 0.5],
                  [1, 0.5]
                ]
              },
              defaultEdge: {
                type: 'line',
                size: 2,
                color: '#e2e2e2',
                style: {
                  endArrow: {
                    path: 'M 0,0 L 8,4 L 8,-4 Z',
                    fill: '#e2e2e2',
                  },
                  radius: 20,
                },
              },
              defaultCombo: {
                type: 'rect',
                size: [300, 50],

                style: {
                  fillOpacity: 0.1,
                      textAlign: "center",
                  fill: "#fff4b5"
                },
              },
            });
            graph.data(data);
            graph.render();
            window.onresize = () => {
                if (!graph || graph.get('destroyed')) return;
                if (!this.el || !this.el.scrollWidth || !this.el.scrollHeight) return;
                graph.changeSize(this.el.scrollWidth, this.el.scrollHeight - 30);
              };
        });
    }
};

export default DagreHook;