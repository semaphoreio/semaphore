
export type FlowStoreType = {
    fitViewNode: (nodeId: string) => void;
    autoSaveFlow: (() => void) | undefined;
    componentsToUpdate: string[];
    setReactFlowInstance: (
      newState: ReactFlowInstance<AllNodeType, EdgeType>,
    ) => void;
    flowState: FlowState | undefined;
    nodes: AllNodeType[];
    edges: EdgeType[];
    onNodesChange: OnNodesChange<AllNodeType>;
    onEdgesChange: OnEdgesChange<EdgeType>;
    setNodes: (
      update: AllNodeType[] | ((oldState: AllNodeType[]) => AllNodeType[]),
    ) => void;
    setEdges: (
      update: EdgeType[] | ((oldState: EdgeType[]) => EdgeType[]),
    ) => void;
    setNode: (
      id: string,
      update: AllNodeType | ((oldState: AllNodeType) => AllNodeType),
      isUserChange?: boolean,
      callback?: () => void,
    ) => void;
    getNode: (id: string) => AllNodeType | undefined;
    deleteNode: (nodeId: string | Array<string>) => void;
    deleteEdge: (edgeId: string | Array<string>) => void;
    paste: (
      selection: { nodes: any; edges: any },
      position: { x: number; y: number; paneX?: number; paneY?: number },
    ) => void;
    lastCopiedSelection: { nodes: any; edges: any } | null;
    setLastCopiedSelection: (
      newSelection: { nodes: any; edges: any } | null,
      isCrop?: boolean,
    ) => void;
    cleanFlow: () => void;
    onConnect: (connection: Connection) => void;
    unselectAll: () => void;
    playgroundPage: boolean;
    getFlow: () => { nodes: Node[]; edges: EdgeType[]; viewport: Viewport };
    getNodePosition: (nodeId: string) => { x: number; y: number };
    handleDragging:
      | {
          source: string | undefined;
          sourceHandle: string | undefined;
          target: string | undefined;
          targetHandle: string | undefined;
          type: string;
          color: string;
        }
      | undefined;
    setHandleDragging: (
      data:
        | {
            source: string | undefined;
            sourceHandle: string | undefined;
            target: string | undefined;
            targetHandle: string | undefined;
            type: string;
            color: string;
          }
        | undefined,
    ) => void;
  };