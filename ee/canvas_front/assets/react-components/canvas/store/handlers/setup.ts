import type { CanvasInitialData } from "../../types";
import type { CanvasState } from "../types";
import { 
  handleStageAdded, 
  handleEventSourceAdded, 
  handleCanvasUpdated 
} from './index';

type HandlerRef = string;

/**
 * Sets up the event handlers for the canvas store
 * Registers listeners for relevant events and returns a cleanup function
 */
export function setupEventHandlers(
  initialData: CanvasInitialData,
  state: CanvasState
): () => void {
  if (!initialData.handleEvent) {
    console.warn("handleEvent not provided to Canvas Store");
    return () => {};
  }

  const handlerRefs: HandlerRef[] = [];

  // Register the stage_added event handler
  const stageAddedRef = initialData.handleEvent('stage_added', (payload) => {
    handleStageAdded(payload, state);
  });
  handlerRefs.push(stageAddedRef);

  // Register the event_source_added event handler
  const eventSourceAddedRef = initialData.handleEvent('event_source_added', (payload) => {
    handleEventSourceAdded(payload, state);
  });
  handlerRefs.push(eventSourceAddedRef);

  // Register the canvas_updated event handler
  const canvasUpdatedRef = initialData.handleEvent('canvas_updated', (payload) => {
    handleCanvasUpdated(payload, state);
  });
  handlerRefs.push(canvasUpdatedRef);

  // Return cleanup function to remove all handlers
  return () => {
    if (initialData.removeHandleEvent) {
      handlerRefs.forEach(ref => initialData.removeHandleEvent(ref));
    }
  };
}
