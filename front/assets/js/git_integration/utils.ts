export const createOrderMap = (orderArray: any[]) =>
  orderArray.reduce((map, type, index) => {
    map[type] = index;
    return map;
  }, {});

export const sortByOrder = (items: any[], orderMap: Record<any, number>) =>
  [...items].sort((a, b) => (orderMap[a] ?? Infinity) - (orderMap[b] ?? Infinity));
