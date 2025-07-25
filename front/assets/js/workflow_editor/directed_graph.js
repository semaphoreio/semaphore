export class DirectedGraph {

  constructor() {
    this.nodes = [];
    this.edges = {};
  }

  addNode(name) {
    this.nodes.push(name)
  }

  addEdge(from, to) {
    if(!this.edges[from]) {
      this.edges[from] = []
    }

    this.edges[from].push(to)
  }

  hasCycle() {
    //
    // The idea behind this algorithm is to check if we can start a walk on the
    // graph and get back to the same node.
    //
    // We initiate this walk from every node in the graph.
    //

    let visited = {};
    let recStack = {};

    //
    // In the begginging, we haven't yet visited any node in the graph.
    //
    for(let i = 0; i < this.nodes.length; i++) {
      visited[this.nodes[i]] = false
      recStack[this.nodes[i]] = false
    }

    //
    // We iterate over each node trying to find a walk back to itself or a walk
    // to any of the already visited nodes in this DFS cycle.
    //
    for(let i = 0; i < this.nodes.length; i++) {
      if(this.isSubtreeCyclic(this.nodes[i], visited, recStack)) {
        return true;
      }
    }

    return false;
  }

  isSubtreeCyclic(rootNode, visited, recStack) {
    if(!visited[rootNode]) {
      // Mark the current node as visited
      visited[rootNode] = true

      // Mark the current node part of the recursion stack
      recStack[rootNode] = true

      // Recur for all the nodes adjacent to this node
      let neighbors = this.edges[rootNode] || []

      for(let i = 0; i < neighbors.length; i++) {
        let node = neighbors[i]

        if(!visited[node] && this.isSubtreeCyclic(node, visited, recStack) ) {
          // Op op, the DFS crossed itself. We found a cycle.
          return true;

        } else if(recStack[node]) {
          // This node was already visited in the walk. Op op, we found a cycle.
          return true;
        }
      }
    }

    //
    // When we finish the recursion starting from this node, we remove the node
    // from the recursion tree. The node is no longer part of the current
    // "recusion stack".
    //
    recStack[rootNode] = false;

    return false;
  }

}
