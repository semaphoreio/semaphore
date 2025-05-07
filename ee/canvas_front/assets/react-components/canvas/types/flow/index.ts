import { Node } from "@xyflow/react";

// Data shape for GitHub Integration node
type LastEvent = { type: string; release: string; timestamp: string };

export type EventSourceNodeData = {
  id: string;
  repoName: string;
  repoUrl: string;
  lastEvent: LastEvent;
  selected: boolean;
}

export type EventSourceNodeType = Node<EventSourceNodeData, 'event_source'>;

export type StageData = {
  label: string;
  labels: string[];
  status?: string;
  timestamp?: string;
  icon?: string;
  queue: string[];
  selected: boolean;
}

export type StageNodeType = Node<StageData, 'stage'>;

