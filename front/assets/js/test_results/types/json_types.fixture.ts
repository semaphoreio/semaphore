import { JSONFailure, JSONTestCase, JSONSuite, JSONSummary, JSONReport } from './json_types';
import { faker } from '@faker-js/faker';

export namespace JSONTypes.Fixture {
  export const Summary = (json?: Partial<JSONSummary>): JSONSummary => {
    return <JSONSummary>{
      total: faker.mersenne.rand(),
      passed: faker.mersenne.rand(),
      skipped: faker.mersenne.rand(),
      error: faker.mersenne.rand(),
      failed: faker.mersenne.rand(),
      duration: faker.mersenne.rand(),
      ...json
    };
  };

  export const Failure = (json?: Partial<JSONFailure>): JSONFailure => {
    return <JSONFailure>{
      message: faker.lorem.sentence(),
      type: faker.random.word(),
      body: faker.lorem.paragraph(),
      ...json
    };
  };

  export const TestCase = (json?: Partial<JSONTestCase>): JSONTestCase => {
    const state = faker.helpers.arrayElement([`passed`, `failed`, `error`, `skipped`, `disabled`]);
    let failure: JSONFailure | undefined;
    let error: JSONFailure | undefined;

    if (state == `failed`) {
      failure = Failure(json?.failure);
    } else if (state == `error`) {
      error = Failure(json?.error);
    }


    return <JSONTestCase>{
      id: faker.datatype.uuid(),
      file: faker.system.filePath(),
      classname: faker.hacker.adjective(),
      package: faker.hacker.noun(),
      name: faker.commerce.productDescription(),
      duration: faker.mersenne.rand(),
      state: state,
      systemOut: ``,
      systemErr: ``,
      failure: failure,
      error: error,
      ...json
    };
  };

  export const Suite = (json?: Partial<JSONSuite>): JSONSuite => {
    const testsCount = faker.mersenne.rand(100, 0);
    const tests = [Array.from({ length: testsCount })].map(() => TestCase());

    return <JSONSuite>{
      id: faker.datatype.uuid(),
      name: faker.commerce.productName(),
      isSkipped: faker.datatype.boolean(),
      isDisabled: faker.datatype.boolean(),
      timestamp: faker.date.past().toISOString(),
      package: faker.hacker.noun(),
      systemErr: faker.lorem.paragraph(),
      systemOut: faker.lorem.paragraph(),
      summary: Summary(json?.summary),
      tests: tests,
      ...json
    };
  };

  export const Report = (json?: Partial<JSONReport>): JSONReport => {
    const suitesCount = faker.mersenne.rand(100, 0);
    const suites = [Array.from({ length: suitesCount })].map(() => Suite());

    return <JSONReport>{
      id: faker.datatype.uuid(),
      name: faker.commerce.productName(),
      framework: faker.commerce.productName(),
      isDisabled: faker.datatype.boolean(),
      summary: Summary(json?.summary),
      suites: suites,
      ...json
    };
  };
}
