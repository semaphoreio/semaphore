import { VNode } from "preact";

export default interface Instruction {
  name: string;
  icon?: string;
  iconElement?: VNode;
  Component: VNode;
}
