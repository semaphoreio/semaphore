import React, { createContext, useContext, FC, ReactNode, useEffect, useReducer } from "react";
import { CanvasInitialData, Stage, EventSource } from "../types";

export interface CanvasContextType {
  canvas: Record<string, any>;
  stages: Stage[];
  event_sources: EventSource[];
  addStage: (stage: Stage) => void;
  updateStage: (stage: Stage) => void;
  addEventSource: (eventSource: EventSource) => void;
  updateEventSource: (eventSource: EventSource) => void;
  updateCanvas: (canvas: Record<string, any>) => void;
  updateNodePosition: (nodeId: string, position: { x: number, y: number }) => void;
}

// Define the state type
interface CanvasState {
  canvas: Record<string, any>;
  stages: Stage[];
  event_sources: EventSource[];
  nodePositions: Record<string, { x: number, y: number }>;
}

// Define action types
type CanvasAction =
  | { type: 'ADD_STAGE'; payload: Stage }
  | { type: 'UPDATE_STAGE'; payload: Stage }
  | { type: 'ADD_EVENT_SOURCE'; payload: EventSource }
  | { type: 'UPDATE_EVENT_SOURCE'; payload: EventSource }
  | { type: 'UPDATE_CANVAS'; payload: Record<string, any> }
  | { type: 'INITIALIZE'; payload: CanvasInitialData }
  | { type: 'UPDATE_NODE_POSITION'; payload: { id: string, position: { x: number, y: number } } };

// Reducer function
const canvasReducer = (state: CanvasState, action: CanvasAction): CanvasState => {
  switch (action.type) {
    case 'INITIALIZE':
      return {
        canvas: action.payload.canvas || {},
        stages: action.payload.stages || [],
        event_sources: action.payload.event_sources || [],
        nodePositions: {}
      };
    case 'ADD_STAGE':
      return {
        ...state,
        stages: [...state.stages, action.payload]
      };
    case 'UPDATE_STAGE':
      return {
        ...state,
        stages: state.stages.map(s => s.id === action.payload.id ? action.payload : s)
      };
    case 'ADD_EVENT_SOURCE':
      return {
        ...state,
        event_sources: [...state.event_sources, action.payload]
      };
    case 'UPDATE_EVENT_SOURCE':
      return {
        ...state,
        event_sources: state.event_sources.map(es => 
          es.id === action.payload.id ? action.payload : es
        )
      };
    case 'UPDATE_CANVAS':
      return {
        ...state,
        canvas: { ...state.canvas, ...action.payload }
      };
    case 'UPDATE_NODE_POSITION':
      return {
        ...state,
        nodePositions: {
          ...state.nodePositions,
          [action.payload.id]: action.payload.position
        }
      };
    default:
      return state;
  }
};

// Default context values
const defaultContextValue: CanvasContextType = {
  canvas: {},
  stages: [],
  event_sources: [],
  addStage: () => {},
  updateStage: () => {},
  addEventSource: () => {},
  updateEventSource: () => {},
  updateCanvas: () => {},
  updateNodePosition: () => {}
};

const CanvasContext = createContext<CanvasContextType>(defaultContextValue);

/**
 * Provides a canvas context backed by React state.
 * Registers callbacks for LiveView events to update the context state.
 */
export const CanvasProvider: FC<{ initialData: CanvasInitialData; children?: ReactNode }> =
  ({ initialData, children }) => {
    // Use reducer for state management
    const [state, dispatch] = useReducer(canvasReducer, {
      canvas: {},
      stages: [],
      event_sources: [],
      nodePositions: {}
    });
    
    // Initialize with initial data (only once)
    useEffect(() => {
      console.log("Initializing Canvas with data:", initialData);
      
      // Initialize state with initial data
      dispatch({ type: 'INITIALIZE', payload: initialData });
      
      console.log("Canvas initialized with stages:", initialData.stages?.length || 0);
    }, [initialData]); // Only run when initialData changes

    // State update handlers
    const addStage = (stage: Stage) => {
      console.log("Adding stage:", stage);
      dispatch({ type: 'ADD_STAGE', payload: stage });
    };
    
    const updateStage = (stage: Stage) => {
      console.log("Updating stage:", stage);
      dispatch({ type: 'UPDATE_STAGE', payload: stage });
    };
    
    const addEventSource = (eventSource: EventSource) => {
      console.log("Adding event source:", eventSource);
      dispatch({ type: 'ADD_EVENT_SOURCE', payload: eventSource });
    };
    
    const updateEventSource = (eventSource: EventSource) => {
      console.log("Updating event source:", eventSource);
      dispatch({ type: 'UPDATE_EVENT_SOURCE', payload: eventSource });
    };
    
    const updateCanvas = (newCanvas: Record<string, any>) => {
      console.log("Updating canvas:", newCanvas);
      dispatch({ type: 'UPDATE_CANVAS', payload: newCanvas });
    };
    
    const updateNodePosition = (nodeId: string, position: { x: number, y: number }) => {
      console.log("Updating node position:", nodeId, position);
      dispatch({ type: 'UPDATE_NODE_POSITION', payload: { id: nodeId, position } });
    };

    // Register LiveView event handlers
    useEffect(() => {
      if (!initialData.handleEvent) {
        console.warn("handleEvent not provided to CanvasProvider");
        return;
      }

      // Handler for stage_added event
      const stageAddedRef = initialData.handleEvent('stage_added', (payload) => {
        const stage = payload as Stage;
        console.log('Stage added event received:', stage);
        
        // Check if stage already exists
        const existingStage = state.stages.find(s => s.id === stage.id);
        if (existingStage) {
          updateStage(stage);
        } else {
          addStage(stage);
        }
      });

      // Handler for event_source_added event
      const eventSourceAddedRef = initialData.handleEvent('event_source_added', (payload) => {
        const eventSource = payload as EventSource;
        console.log('Event source added:', eventSource);
        
        // Check if event source already exists
        const existingSource = state.event_sources.find(es => es.id === eventSource.id);
        if (existingSource) {
          updateEventSource(eventSource);
        } else {
          addEventSource(eventSource);
        }
      });

      // Handler for canvas_updated event
      const canvasUpdatedRef = initialData.handleEvent('canvas_updated', (canvasData) => {
        console.log('Canvas updated:', canvasData);
        updateCanvas(canvasData);
      });

      // Clean up event handlers when component unmounts
      return () => {
        if (initialData.removeHandleEvent) {
          initialData.removeHandleEvent(stageAddedRef);
          initialData.removeHandleEvent(eventSourceAddedRef);
          initialData.removeHandleEvent(canvasUpdatedRef);
        }
      };
    }, [initialData, state.stages, state.event_sources]); // Dependencies

    // Create context value
    const contextValue: CanvasContextType = {
      canvas: state.canvas,
      stages: state.stages,
      event_sources: state.event_sources,
      addStage,
      updateStage,
      addEventSource,
      updateEventSource,
      updateCanvas,
      updateNodePosition
    };

    return (
      <CanvasContext.Provider value={contextValue}>
        {children}
      </CanvasContext.Provider>
    );
  };

export const useCanvasContext = (): CanvasContextType => {
  const context = useContext(CanvasContext);
  if (!context) {
    throw new Error("useCanvasContext must be used within a CanvasProvider");
  }
  return context;
};
