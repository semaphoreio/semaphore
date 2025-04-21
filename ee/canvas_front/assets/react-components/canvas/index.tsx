import React, { StrictMode, useEffect } from "react";
import { CanvasProvider } from "./contexts/CanvasContext";
import { FlowRenderer } from "./components/FlowRenderer";
import { useLiveReact } from "live_react";
import type { Stage, EventSource } from "./types";

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
  
  useEffect(() => {
    console.log("Canvas mounted with:", {
      canvas: JSON.stringify(canvas),
      stagesCount: stages.length,
      eventSourcesCount: event_sources.length
    });
  }, [canvas, stages, event_sources]);
  
  // Now including the required handleEvent and removeHandleEvent properties
  const providerData = {
    canvas,
    stages: Array.isArray(stages) ? stages : [], 
    event_sources: Array.isArray(event_sources) ? event_sources : [],
    handleEvent, 
    removeHandleEvent
  };
  
  return (
    <StrictMode>
      <CanvasProvider initialData={providerData}>
        <FlowRenderer />
      </CanvasProvider>
    </StrictMode>
  );
}
