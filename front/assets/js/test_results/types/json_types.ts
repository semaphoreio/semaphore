export interface JSONFailure {
  message: string;
  body: string;
  type: string;
}

export interface JSONTestCase {
  id: string;
  file: string;
  classname: string;
  package: string;
  name: string;
  duration: number;
  state: string;
  systemOut: string;
  systemErr: string;
  failure?: JSONFailure;
  error?: JSONFailure;
}

export interface JSONSummary {
  total: number;
  passed: number;
  skipped: number;
  error: number;
  failed: number;
  duration: number;
}

export interface JSONSuite {
  id: string;
  name: string;
  isSkipped: boolean;
  isDisabled: boolean;
  timestamp: string;
  package: string;

  systemErr: string;
  systemOut: string;
  summary: JSONSummary;
  properties?: Record<string, string>;
  tests: Array<JSONTestCase>;
}

export interface JSONReport {
  id: string;
  name: string;
  framework: string;
  isDisabled: boolean;
  status: string;
  statusMessage: string;
  suites: Array<JSONSuite>;
  summary: JSONSummary;
}

export interface JSONReports {
  testResults: Array<JSONReport>;
}
