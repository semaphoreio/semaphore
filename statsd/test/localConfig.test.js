const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const configPath = path.join(__dirname, "..", "localConfig.js");
const configSource = fs.readFileSync(configPath, "utf8");

const loadConfig = (envOverrides) => {
  const context = {
    parseInt,
    process: { env: { ...envOverrides } },
  };

  return vm.runInNewContext(`(${configSource})`, context);
};

test("localConfig.js parses and exposes expected defaults", () => {
  const config = loadConfig({
    DUMP_MESSAGES: "false",
    FLUSH_INTERVAL: "60000",
    GRAPHITE_HOST: "metric.example.com",
  });

  assert.equal(config.port, 8125);
  assert.equal(config.graphiteHost, "metric.example.com");
  assert.equal(config.graphitePort, 2003);
  assert.equal(config.graphite.legacyNamespace, false);
  assert.equal(Array.isArray(config.backends), true);
  assert.equal(config.backends.length, 1);
  assert.equal(config.backends[0], "./backends/graphite");
  assert.equal(config.debug, true);
  assert.equal(config.dumpMessages, false);
  assert.equal(config.flushInterval, 60000);
  assert.equal(config.deleteGauges, true);
  assert.equal(config.deleteCounters, true);
});

test("DUMP_MESSAGES enables dumpMessages", () => {
  const config = loadConfig({
    DUMP_MESSAGES: "true",
    FLUSH_INTERVAL: "60000",
    GRAPHITE_HOST: "metric.example.com",
  });

  assert.equal(config.dumpMessages, true);
});
