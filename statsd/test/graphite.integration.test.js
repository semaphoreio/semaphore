const assert = require("node:assert/strict");
const dgram = require("node:dgram");
const fs = require("node:fs");
const net = require("node:net");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");
const { once } = require("node:events");
const test = require("node:test");

const statsdRoot = path.join(__dirname, "..");
const statsdBin = path.join(statsdRoot, "node_modules", ".bin", "statsd");

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const parseGraphiteLine = (line) => {
  const [metric, value, timestamp] = line.trim().split(/\s+/);

  return {
    metric,
    value: Number.parseFloat(value),
    timestamp: Number.parseInt(timestamp, 10),
  };
};

const createGraphiteServer = async () => {
  const lines = [];
  const handlers = new Set();
  const server = net.createServer((socket) => {
    let buffer = "";

    socket.on("data", (chunk) => {
      buffer += chunk.toString("utf8");
      while (buffer.includes("\n")) {
        const index = buffer.indexOf("\n");
        const line = buffer.slice(0, index).trim();
        buffer = buffer.slice(index + 1);
        if (!line) continue;
        lines.push(line);
        for (const handler of handlers) {
          handler(line);
        }
      }
    });
  });

  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));

  const waitForLine = (predicate, timeoutMs = 2000) =>
    new Promise((resolve, reject) => {
      const existing = lines.find(predicate);
      if (existing) {
        resolve(existing);
        return;
      }

      const handler = (line) => {
        if (predicate(line)) {
          cleanup();
          resolve(line);
        }
      };
      const timeout = setTimeout(() => {
        cleanup();
        reject(
          new Error(
            `Timed out waiting for graphite line; received: ${lines.join(", ")}`
          )
        );
      }, timeoutMs);
      const cleanup = () => {
        clearTimeout(timeout);
        handlers.delete(handler);
      };

      handlers.add(handler);
    });

  return { server, port: server.address().port, waitForLine };
};

const getFreeUdpPort = () =>
  new Promise((resolve, reject) => {
    const socket = dgram.createSocket("udp4");
    socket.on("error", reject);
    socket.bind(0, "127.0.0.1", () => {
      const { port } = socket.address();
      socket.close(() => resolve(port));
    });
  });

const sendMetrics = async (port, messages) => {
  const socket = dgram.createSocket("udp4");
  for (const message of messages) {
    await new Promise((resolve, reject) => {
      socket.send(message, port, "127.0.0.1", (err) =>
        err ? reject(err) : resolve()
      );
    });
  }
  socket.close();
};

const buildConfig = (statsdPort, graphitePort, flushIntervalMs) => `{
  port: ${statsdPort}
, address: "127.0.0.1"
, graphiteHost: "127.0.0.1"
, graphitePort: ${graphitePort}
, graphite: { legacyNamespace: false }
, backends: ["./backends/graphite"]
, debug: false
, dumpMessages: false
, flushInterval: ${flushIntervalMs}
, deleteGauges: true
, deleteCounters: true
}
`;

const shutdownProcess = async (child) => {
  if (!child || child.exitCode !== null || child.signalCode !== null) return;
  child.kill("SIGTERM");
  const exited = await Promise.race([once(child, "exit"), wait(1000)]);
  if (!exited && child.exitCode === null && child.signalCode === null) {
    child.kill("SIGKILL");
    await once(child, "exit");
  }
};

test("statsd flushes metrics to graphite", async () => {
  if (!fs.existsSync(statsdBin)) {
    throw new Error(`statsd binary not found at ${statsdBin}; run npm install`);
  }

  const graphite = await createGraphiteServer();
  const statsdPort = await getFreeUdpPort();
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "statsd-test-"));
  const configPath = path.join(tmpDir, "statsd-config.js");
  const statsdOutput = [];
  let statsd;

  try {
    fs.writeFileSync(configPath, buildConfig(statsdPort, graphite.port, 100));

    statsd = spawn(statsdBin, [configPath], {
      cwd: statsdRoot,
      stdio: ["ignore", "pipe", "pipe"],
    });
    statsd.stdout.on("data", (chunk) =>
      statsdOutput.push(chunk.toString("utf8"))
    );
    statsd.stderr.on("data", (chunk) =>
      statsdOutput.push(chunk.toString("utf8"))
    );

    await wait(100);
    if (statsd.exitCode !== null || statsd.signalCode !== null) {
      throw new Error(
        `statsd exited early (${statsd.exitCode}); output: ${statsdOutput.join(
          ""
        )}`
      );
    }

    await sendMetrics(statsdPort, [
      "statsd_test.counter:1|c",
      "statsd_test.counter:1|c",
      "statsd_test.gauge:42|g",
    ]);

    const counterMetricNames = [
      "stats.counters.statsd_test.counter.count",
      "statsd_test.counter.count",
      "statsd_test.counter",
    ];
    const gaugeMetricNames = ["stats.gauges.statsd_test.gauge", "statsd_test.gauge"];
    const lineStartsWith = (metricNames, line) =>
      metricNames.some((name) => line.startsWith(`${name} `));

    const counterLine = await graphite.waitForLine((line) =>
      lineStartsWith(counterMetricNames, line)
    );
    const gaugeLine = await graphite.waitForLine((line) =>
      lineStartsWith(gaugeMetricNames, line)
    );

    const counter = parseGraphiteLine(counterLine);
    const gauge = parseGraphiteLine(gaugeLine);

    assert.equal(counter.value, 2);
    assert.equal(gauge.value, 42);
  } finally {
    await shutdownProcess(statsd);
    await new Promise((resolve) => graphite.server.close(resolve));
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});
