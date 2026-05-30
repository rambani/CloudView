import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeLogger } from '../api/lib/observability.js';

/// Capture console output so we can assert on what got logged. Each test
/// installs a fresh shim and restores afterward.
function captureConsole() {
  const logs: string[] = [];
  const errors: string[] = [];
  const origLog = console.log;
  const origErr = console.error;
  console.log = (...args: unknown[]) => { logs.push(String(args[0])); };
  console.error = (...args: unknown[]) => { errors.push(String(args[0])); };
  return {
    logs,
    errors,
    restore() { console.log = origLog; console.error = origErr; },
  };
}

function mockRequest(headers: Record<string, string> = {}): Request {
  return new Request('https://example.test/', {
    method: 'POST',
    headers: new Headers(headers),
  });
}

test('logger emits one JSON line per call with shared request_id', () => {
  const c = captureConsole();
  try {
    const log = makeLogger(mockRequest({ 'x-vercel-id': 'abc123' }), 'test-handler');
    log.event('hello', { foo: 'bar' });
    log.done(200);

    assert.equal(c.logs.length, 2);
    const first = JSON.parse(c.logs[0]!);
    const second = JSON.parse(c.logs[1]!);
    assert.equal(first.request_id, 'abc123');
    assert.equal(second.request_id, 'abc123', 'request_id must be stable within one logger');
    assert.equal(first.handler, 'test-handler');
    assert.equal(first.kind, 'hello');
    assert.equal(first.foo, 'bar');
    assert.equal(second.kind, 'request_done');
    assert.equal(second.status, 200);
    assert.equal(typeof second.latency_ms, 'number');
    assert.ok(second.latency_ms >= 0);
  } finally {
    c.restore();
  }
});

test('logger uses a generated request_id when no header is present', () => {
  const c = captureConsole();
  try {
    const log = makeLogger(mockRequest(), 'test-handler');
    log.event('hello');
    const line = JSON.parse(c.logs[0]!);
    assert.ok(line.request_id, 'request_id must be set');
    assert.match(line.request_id, /^[0-9a-f-]{36}$/);  // UUID format
  } finally {
    c.restore();
  }
});

test('logger routes .error to console.error not console.log', () => {
  const c = captureConsole();
  try {
    const log = makeLogger(mockRequest(), 'test-handler');
    log.error('something_broke', { detail: 'x' });
    assert.equal(c.logs.length, 0);
    assert.equal(c.errors.length, 1);
    const line = JSON.parse(c.errors[0]!);
    assert.equal(line.level, 'error');
    assert.equal(line.kind, 'something_broke');
    assert.equal(line.detail, 'x');
  } finally {
    c.restore();
  }
});

test('logger captures IP from x-forwarded-for', () => {
  const c = captureConsole();
  try {
    const log = makeLogger(
      mockRequest({ 'x-forwarded-for': '1.2.3.4, 5.6.7.8' }),
      'test-handler'
    );
    log.event('hello');
    const line = JSON.parse(c.logs[0]!);
    assert.equal(line.ip, '1.2.3.4');
  } finally {
    c.restore();
  }
});
