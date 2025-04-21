import React, { useMemo, useEffect, useCallback } from "react";
import { ReactFlow, Controls, Background, useNodesState, useEdgesState, Node } from "@xyflow/react";
import { useCanvasContext } from "../contexts/CanvasContext";
import '@xyflow/react/dist/style.css';


import DeploymentCard from '../components/nodes/DeploymentCard';
import GithubIntegration from '../components/nodes/GithubIntegration';
import type { NodeTypes } from '@xyflow/react';
import type { ComponentType } from 'react';

// Cast our components to satisfy ReactFlow's NodeTypes requirements
export const nodeTypes = {
  deploymentCard: DeploymentCard as ComponentType<any>,
  githubIntegration: GithubIntegration as ComponentType<any>,
} as unknown as NodeTypes;

/**
 * Renders the canvas data as React Flow nodes and edges.
 */
export const FlowRenderer: React.FC = () => {
  const { stages, event_sources, updateNodePosition } = useCanvasContext();
  
  // Create initial nodes and edges (only run once when the data changes)
  const initialNodes = useMemo(() => 
    [
      ...event_sources.map((es, idx) => ({ 
        id: es.id, 
        type: 'githubIntegration', 
        data: { 
          label: es.name, 
          repoName: es.name, 
          repoUrl: es.url, 
          lastEvent: { 
            type: 'push', 
            release: 'v1.0.0', 
            timestamp: '2023-01-01T00:00:00' 
          } 
        }, 
        position: { x: 0, y: idx * 320 },
        draggable: true
      })),
      ...stages.map((st, idx) => ({ 
        id: st.id, 
        type: 'deploymentCard', 
        data: { 
          label: st.name, 
          labels: st.labels, 
          status: st.status, 
          timestamp: st.timestamp, 
          icon: st.icon, 
          queue: st.queue 
        }, 
        position: { x: 600, y: idx * 320 },
        draggable: true
      })),
    ],
  [event_sources, stages]);
  
  const initialEdges = useMemo(() =>
    stages.flatMap((st) =>
      (st.connections || []).map((conn: any) => {
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

  // Use React Flow's built-in state management
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);
  
  // Handler for when node dragging stops
  const onNodeDragStop = useCallback(
    (_: React.MouseEvent, node: Node) => {
      console.log("Node dragged to:", node.id, node.position);
      updateNodePosition(node.id, node.position);
    },
    [updateNodePosition]
  );
  
  // Update nodes and edges when source data changes
  useEffect(() => {
    setNodes(initialNodes);
    setEdges(initialEdges);
  }, [initialNodes, initialEdges, setNodes, setEdges]);

  return (
    <div style={{ width: "100vw", height: "100vh", minWidth: 0, minHeight: 0 }}>
      <ReactFlow
        nodes={nodes}
        edges={edges}
        nodeTypes={nodeTypes}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onNodeDragStop={onNodeDragStop}
        onInit={(instance) => instance.fitView()}
        minZoom={0.4}
        maxZoom={1.5}
      >
        <Controls />
        <Background />
      </ReactFlow>
    </div>
  );
};
