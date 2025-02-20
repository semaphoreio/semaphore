export interface FilterOption {
  value: string;
  label: string;
}

export interface Filter {
  label: string;
  type: `radio` | `multiple`;
  searchField: string;
  options: FilterOption[];
}

export interface Group {
  name: string;
  label: string;
}

export interface Template {
  workflow_tip?: string;
  short_description: string;
  title: string;
  template_path: string;
  template_content: string;
  preview?: string;
  pinned?: boolean;
  icon: string;
  group?: string;
  features: string[];
  description: string;
  category?: string;
  tags?: string[];
  environment?: string;
}

export interface TemplatesSetup {
  groups: Group[];
  filters: Filter[];
}