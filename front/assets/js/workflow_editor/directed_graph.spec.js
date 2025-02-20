import { expect } from "chai"
import { DirectedGraph } from "./directed_graph"

describe("DirectedGraph", () => {

  describe("#hasCycle", () => {
    describe("simple linear graph", () => {
      it("has no cycles", () => {
        //
        // a -> b -> c
        //

        let g = new DirectedGraph()
        g.addNode("a")
        g.addNode("b")
        g.addNode("c")

        g.addEdge("a", "b")
        g.addEdge("b", "c")

        expect(g.hasCycle()).to.equal(false)
      })
    })

    describe("simple tree", () => {
      it("has no cycles", () => {
        //
        // a -> b
        //   -> c
        //

        let g = new DirectedGraph()
        g.addNode("a")
        g.addNode("b")
        g.addNode("c")

        g.addEdge("a", "b")
        g.addEdge("a", "c")

        expect(g.hasCycle()).to.equal(false)
      })
    })

    describe("circle", () => {
      it("has cycles", () => {
        //
        // a -> b -> c
        // |         |
        // ^ ------- <
        //

        let g = new DirectedGraph()
        g.addNode("a")
        g.addNode("b")
        g.addNode("c")

        g.addEdge("a", "b")
        g.addEdge("b", "c")
        g.addEdge("c", "c")

        expect(g.hasCycle()).to.equal(true)
      })
    })

    describe("fan-in", () => {
      it("has no cycles", () => {
        //
        //      | -> b -> |
        // a -> |         | -> d
        //      | -> c -> |
        //

        let g = new DirectedGraph()
        g.addNode("a")
        g.addNode("b")
        g.addNode("c")
        g.addNode("d")

        g.addEdge("a", "b")
        g.addEdge("a", "c")
        g.addEdge("b", "d")
        g.addEdge("c", "d")

        expect(g.hasCycle()).to.equal(false)
      })
    })
  })

})
