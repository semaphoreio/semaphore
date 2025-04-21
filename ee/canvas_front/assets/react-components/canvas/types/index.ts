// Define interfaces for our data types to ensure type safety
export interface Stage {
  id: string;
  name: string;
  status?: string;
  labels?: string[];
  timestamp?: string;
  icon?: string;
  queue?: any[];
  connections?: Array<{name: string}>;
  [key: string]: any;
}

export interface EventSource {
  id: string;
  name: string;
  url?: string;
  [key: string]: any;
}

export interface CanvasData {
  canvas: Record<string, any>;
  stages: Stage[];
  event_sources: EventSource[];
}

// We need this type for the live_react handlers
export interface LiveReactHandlers {
  handleEvent: (event: string, callback: (payload: Record<string, any>) => void) => string;
  removeHandleEvent: (callbackRef: string) => void;
}

export interface CanvasInitialData extends CanvasData {
  handleEvent: LiveReactHandlers['handleEvent'];
  removeHandleEvent: LiveReactHandlers['removeHandleEvent'];
}
