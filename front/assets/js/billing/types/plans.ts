export class Plan {
  name: string;
  type: string;
  description: string;

  static fromJSON(json: any): Plan {
    const p = new Plan();

    p.name = json.name as string;
    p.type = json.type as string;
    p.description = json.description as string;

    return p;
  }
}
