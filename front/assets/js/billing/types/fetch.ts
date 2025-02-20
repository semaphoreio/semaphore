
export enum Status {
  Empty = `empty`,
  Loading = `loading`,
  Loaded = `loaded`,
  Error = `error`,
}

export interface Fetchable<T> {
  url: string;
  status: Status;
  statusMessage: string;
  result?: T;
}
