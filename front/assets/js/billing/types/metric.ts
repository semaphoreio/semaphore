export interface Interface {
  get name(): string;
  get value(): number;
  set value(value: number);
  get date(): Date;
  get hexColor(): string;
  isEmpty(): boolean;
}
