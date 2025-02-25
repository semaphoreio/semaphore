export const createOrderMap = (orderArray: any[]) =>
  orderArray.reduce((map, type, index) => {
    map[type] = index;
    return map;
  }, {});

export const sortByOrder = <T>(items: T[], orderMap: Record<any, number>) =>
  [...items].sort((a, b) => (orderMap[a] ?? Infinity) - (orderMap[b] ?? Infinity));

export const sortObjectByOrder = <T>(items: T[], orderMap: Record<any, number>, key: string) =>
  [...items].sort((a, b) => (orderMap[a[key]] ?? Infinity) - (orderMap[b[key]] ?? Infinity));
