import { WorkspaceData } from "../types";

export interface Wire {
  from: string;
  to: string;
  kind?: `flow` | `outcome`;
}

export const OUTCOME_NODE = `__outcome__`;

export const workspaceWires = (data: WorkspaceData): Wire[] => {
  const blocks = data.current.blocks;
  const dependedOn = new Set(blocks.flatMap((block) => block.deps));
  const wires: Wire[] = [];

  blocks.forEach((block) => {
    block.deps.forEach((dep) => {
      wires.push({ from: dep, to: block.name, kind: `flow` });
    });
  });

  blocks
    .filter((block) => !dependedOn.has(block.name))
    .forEach((block) => {
      wires.push({ from: block.name, to: OUTCOME_NODE, kind: `outcome` });
    });

  data.current.promotions.forEach((promotion) => {
    wires.push({ from: OUTCOME_NODE, to: promotion.name, kind: `outcome` });
  });

  return wires;
};

const WIRE_COLORS: Record<string, string> = {
  flow: `#b4c0c0`,
  outcome: `#b4c0c0`,
};

export const drawWires = (canvas: HTMLElement, wires: Wire[]): void => {
  const svg = canvas.querySelector(`svg[data-wires]`);

  if (!svg) {
    return;
  }

  svg.setAttribute(`width`, `${canvas.scrollWidth}`);
  svg.setAttribute(`height`, `${canvas.scrollHeight}`);

  while (svg.firstChild) {
    svg.removeChild(svg.firstChild);
  }

  const canvasRect = canvas.getBoundingClientRect();
  const nodeRect = (name: string) => {
    const node = canvas.querySelector(`[data-node="${CSS.escape(name)}"]`);

    return node ? node.getBoundingClientRect() : null;
  };

  wires.forEach((wire) => {
    const from = nodeRect(wire.from);
    const to = nodeRect(wire.to);

    if (!from || !to) {
      return;
    }

    const x1 = from.right - canvasRect.left;
    const y1 = from.top + from.height / 2 - canvasRect.top;
    const x2 = to.left - canvasRect.left;
    const y2 = to.top + to.height / 2 - canvasRect.top;
    const bend = Math.max(24, (x2 - x1) / 2);

    const path = document.createElementNS(`http://www.w3.org/2000/svg`, `path`);
    path.setAttribute(`d`, `M ${x1} ${y1} C ${x1 + bend} ${y1}, ${x2 - bend} ${y2}, ${x2} ${y2}`);
    path.setAttribute(`fill`, `none`);
    path.setAttribute(`stroke`, WIRE_COLORS[wire.kind || `flow`]);
    path.setAttribute(`stroke-width`, `1.5`);
    svg.appendChild(path);
  });
};
