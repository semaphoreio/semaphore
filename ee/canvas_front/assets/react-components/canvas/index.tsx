import React, { StrictMode, useEffect } from "react";
import { FlowRenderer } from "./components/FlowRenderer";
import { useLiveReact } from "live_react";
import type { Stage, EventSource } from "./types";
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
  const { handleEvent, pushEvent, removeHandleEvent } = useLiveReact();
  const { initialize, setupLiveViewHandlers } = useCanvasStore();
  
  useEffect(() => {
    // Initialize the store with the provided data
    const initialData = {
      canvas,
      stages: Array.isArray(stages) ? stages : [], 
      event_sources: Array.isArray(event_sources) ? event_sources : [],
      handleEvent, 
      removeHandleEvent,
      pushEvent
    };
    
    initialize(initialData);
    
    // Set up LiveView event handlers and get cleanup function
    const cleanup = setupLiveViewHandlers(initialData);
    
    // Return cleanup function to remove event handlers on unmount
    return cleanup;
  }, [canvas, stages, event_sources, handleEvent, removeHandleEvent, initialize, setupLiveViewHandlers]);
  
  return (
    <StrictMode>
        <FlowRenderer />
    </StrictMode>
  );
}
