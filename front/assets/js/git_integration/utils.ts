export const createOrderMap = <T extends PropertyKey>(orderArray: T[]): Record<T, number> =>
  orderArray.reduce((map, type, index) => {
    map[type] = index;
    return map;
  }, {} as Record<T, number>);

export const sortByOrder = <T extends PropertyKey>(items: T[], orderMap: Record<T, number>) =>
  [...items].sort((a, b) => (orderMap[a] ?? Infinity) - (orderMap[b] ?? Infinity));

export const sortObjectByOrder = <T extends Record<string, any>>(
  items: T[],
  orderMap: Record<PropertyKey, number>,
  key: keyof T,
) =>
  [...items].sort((a, b) => (orderMap[a[key]] ?? Infinity) - (orderMap[b[key]] ?? Infinity));
