import React, { useMemo, useCallback } from "react";
import { ReactFlow, Controls, Background, Node, NodeTypes, Edge } from "@xyflow/react";
import { useCanvasStore } from "../store/canvasStore";
import '@xyflow/react/dist/style.css';


import StageNode from './nodes/stage';
import GithubIntegration from './nodes/event_source';
import { FlowDevTools } from './devtools';

export const nodeTypes = {
  deploymentCard: StageNode,
  githubIntegration: GithubIntegration,
}

/**
 * Renders the canvas data as React Flow nodes and edges.
 */
export const FlowRenderer: React.FC = () => {
  const { stages, event_sources, nodePositions, updateNodePosition } = useCanvasStore();
  
  // Create nodes from our canvasStore data
  const nodes = useMemo(() => [
    ...event_sources.map((es, idx) => ({ 
      id: es.id, 
      type: 'githubIntegration' as keyof NodeTypes, 
      data: { 
        label: es.name, 
        repoName: es.name, 
        repoUrl: es.url, 
        lastEvent: es.lastEvent || { 
          type: 'push', 
          release: 'v1.0.0', 
          timestamp: '2023-01-01T00:00:00' 
        }
      }, 
      // Use stored position if available, otherwise use default position
      position: nodePositions[es.id] || { x: 0, y: idx * 320 },
      draggable: true
    })),
    ...stages.map((st, idx) => ({ 
      id: st.id, 
      type: 'deploymentCard' as keyof NodeTypes, 
      data: { 
        label: st.name, 
        labels: st.labels || [], 
        status: st.status, 
        timestamp: st.timestamp, 
        icon: st.icon || "storage", 
        queue: st.queue || [], 
        connections: st.connections || [], 
        conditions: st.conditions || [], 
        run_template: st.run_template
      }, 
      // Use stored position if available, otherwise use default position
      position: nodePositions[st.id] || { x: 600, y: idx * 320 },
      draggable: true
    })),
  ], [event_sources, stages, nodePositions]);
  
  // Create edges from our canvasStore data
  const edges = useMemo<Edge[]>(() =>
    stages.flatMap((st) =>
      (st.connections || []).map((conn) => {
        const isEvent = event_sources.some((es) => es.name === conn.name);
        const sourceObj =
          event_sources.find((es) => es.name === conn.name) ||
          stages.find((s) => s.name === conn.name);
        const sourceId = sourceObj?.id ?? conn.name;
        return { 
          id: `e-${conn.name}-${st.id}`, 
          source: sourceId, 
          target: st.id, 
          type: "smoothstep", 
          animated: true, 
          style: isEvent ? { stroke: '#FF0000', strokeWidth: 2 } : undefined 
        };
      })
    ),
    [event_sources, stages]
  );

  // We don't need React Flow's built-in state management anymore
  // Our state is managed entirely by our canvasStore
  
  // Handler for when node dragging stops
  const onNodeDragStop = useCallback(
    (_: React.MouseEvent, node: Node) => {
      console.log("Node dragged to:", node.id, node.position);
      updateNodePosition(node.id, node.position);
    },
    [updateNodePosition]
  );
  
  // No need for useEffect to sync state since we're using canvasStore directly

  return (
    <div style={{ width: "100vw", height: "100vh", minWidth: 0, minHeight: 0 }}>
        <ReactFlow
          nodes={nodes}
          edges={edges}
          nodeTypes={nodeTypes}
          onNodesChange={() => {/* Node changes are handled by the store */}}
          onEdgesChange={() => {/* Edge changes are handled by the store */}}
          onNodeDragStop={onNodeDragStop}
          onInit={(instance) => instance.fitView()}
          minZoom={0.4}
          maxZoom={1.5}
        >
          <Controls />
          <Background />
          <FlowDevTools />
        </ReactFlow>
    </div>
  );
};
