export const pluralize = (count: number, string: string): string => {
  if(count > 1 || count == 0) {
    return `${count} ${string}s`;
  } else {
    return `${count} ${string}`;
  }
};
