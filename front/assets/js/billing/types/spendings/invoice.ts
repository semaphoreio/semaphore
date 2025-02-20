export class Invoice {
  name: string;
  url: string;
  total: string;

  static fromJSON(json: any): Invoice {
    const i = new Invoice();

    i.name = json.name as string;
    i.url = json.url as string;
    i.total = json.total as string;

    return i;
  }
}
