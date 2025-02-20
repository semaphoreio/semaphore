

export const metricFromNumber = (metric: number) => {
  const map = new Map<number, string>();
  map.set(1, `Performance`);
  map.set(2, `Frequency`);
  map.set(3, `Reliability`);

  return map.get(metric);
};
