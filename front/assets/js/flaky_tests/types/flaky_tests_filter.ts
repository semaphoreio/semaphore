
export class FlakyTestsFilter {
  id: string;
  name: string;
  value: string;


  static fromJSON(json: any): FlakyTestsFilter {
    const filter = new FlakyTestsFilter();
    filter.id = json.id as string;
    filter.name = json.name as string;
    filter.value = json.value as string;

    return filter;
  }
}