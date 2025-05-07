import React, { StrictMode, useEffect } from "react";
import { FlowRenderer } from "./components/FlowRenderer";
import { useLiveReact } from "live_react";
import type { Stage, EventSource } from "./types";
import { ReactFlowProvider } from "@xyflow/react";
import { useCanvasStore } from "./store/canvasStore";

interface CanvasProps {
  canvas?: Record<string, any>;
  stages?: Stage[];
  event_sources?: EventSource[];
}

export function Canvas({
  canvas = {},
  stages = [],
  event_sources = [],
}: CanvasProps) {
  const { handleEvent, removeHandleEvent } = useLiveReact();
  const { initialize, setupLiveViewHandlers } = useCanvasStore();
  
  useEffect(() => {
    console.log("Canvas mounted with:", {
      canvas: JSON.stringify(canvas),
      stagesCount: stages.length,
      eventSourcesCount: event_sources.length
    });
    
    // Initialize the store with the provided data
    const initialData = {
      canvas,
      stages: Array.isArray(stages) ? stages : [], 
      event_sources: Array.isArray(event_sources) ? event_sources : [],
      handleEvent, 
      removeHandleEvent
    };
    
    initialize(initialData);
    
    // Set up LiveView event handlers and get cleanup function
    const cleanup = setupLiveViewHandlers(initialData);
    
    // Return cleanup function to remove event handlers on unmount
    return cleanup;
  }, [canvas, stages, event_sources, handleEvent, removeHandleEvent, initialize, setupLiveViewHandlers]);
  
  return (
    <StrictMode>
      <ReactFlowProvider>
        <FlowRenderer />
      </ReactFlowProvider>
    </StrictMode>
  );
}
