import { Node } from "@xyflow/react";

export type StageNodeType = Node<StageData, "stage">;

export type StageData = {

}

export type EventSourceData = {
  label: string;
  labels: string[];
  status?: string;
  timestamp?: string;
  icon?: string;
  queue: string[];
  selected: boolean;
}

export type EventSourceNodeType = Node<EventSourceData, 'deploymentCard'>;

