import { CanvasInitialData, Stage, EventSource } from "../types";
import { LiveProps } from "live_react";

// Define the store state type
export interface CanvasState {
  canvas: Record<string, any>;
  stages: Stage[];
  event_sources: EventSource[];
  nodePositions: Record<string, { x: number, y: number }>;
  handleEvent?: LiveProps['handleEvent'];
  removeHandleEvent?: LiveProps['removeHandleEvent'];
  pushEvent?: LiveProps['pushEvent'];
  
  // Actions
  initialize: (data: CanvasInitialData) => void;
  addStage: (stage: Stage) => void;
  updateStage: (stage: Stage) => void;
  addEventSource: (eventSource: EventSource) => void;
  updateEventSource: (eventSource: EventSource) => void;
  updateCanvas: (canvas: Record<string, any>) => void;
  updateNodePosition: (nodeId: string, position: { x: number, y: number }) => void;
  approveStageEvent: (stageEventId: string, stageId: string) => void;
  
  // Utility to setup LiveView event handlers
  setupLiveViewHandlers: (initialData: CanvasInitialData) => () => void;
}
