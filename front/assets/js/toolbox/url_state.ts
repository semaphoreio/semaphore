export const set = (name: string, value: string): void => {
  const params = new URLSearchParams(location.search);
  params.set(name, value);

  window.history.replaceState({}, ``, `${location.pathname}?${params.toString()}`);
};

export const get = (name: string, def = ``): string => {
  const params = new URLSearchParams(location.search);
  if (params.has(name)) {
    return params.get(name);
  } else {
    return def;
  }
};

export const unset = (name: string): void => {
  const params = new URLSearchParams(location.search);
  params.delete(name);

  window.history.replaceState({}, ``, `${location.pathname}?${params.toString()}`);
};
