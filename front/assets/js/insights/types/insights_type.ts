

export enum InsightsType {
  Performance = 1,
  Frequency = 2,
  Reliability = 3,
}

export const typeByMetric = (metric: number) => {
  switch (metric) {
    case 1:
      return InsightsType.Performance;
    case 2:
      return InsightsType.Frequency;
    case 3:
      return InsightsType.Reliability;
    default:
      return InsightsType.Performance;
  }
};