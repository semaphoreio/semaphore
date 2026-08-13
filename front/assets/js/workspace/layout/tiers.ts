import { Block } from "../types";

export const dependencyTiers = (blocks: Block[]): Block[][] => {
  const knownNames = new Set(blocks.map((block) => block.name));
  const placedNames = new Set<string>();
  const tiers: Block[][] = [];

  let pending = blocks.slice();

  while (pending.length > 0) {
    const ready = pending.filter((block) =>
      block.deps.every((dep) => !knownNames.has(dep) || placedNames.has(dep))
    );

    if (ready.length === 0) {
      tiers.push(pending);
      break;
    }

    ready.forEach((block) => placedNames.add(block.name));
    tiers.push(ready);
    pending = pending.filter((block) => !placedNames.has(block.name));
  }

  return tiers;
};
