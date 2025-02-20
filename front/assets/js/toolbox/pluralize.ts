
export default function(num: number, single: string, plural: string, formatValue: (value: number) => string = (value) => `${value}` ): string {
  if (num === 1) {
    return `${formatValue(num)} ${single}`;
  } else {
    return `${formatValue(num)} ${plural}`;
  }
}
