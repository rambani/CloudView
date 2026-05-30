// Lightweight structured logging for backend handlers. No vendor
// dependency — Vercel surfaces console.log JSON in its log explorer,
// and the structure makes it easy to grep/jq for support.
//
// Usage:
//   const log = makeLogger(req, 'report-scan');
//   log.event('threshold_crossed', { category, region, count });
//   log.error('apns_send_failed', { reason });
//   log.done(200);  // call once per handler, just before return
//
// All log lines share a request_id so a single user action can be
// traced end-to-end across the lifetime of one request.

export interface Logger {
  event(kind: string, fields?: Record<string, unknown>): void;
  error(kind: string, fields?: Record<string, unknown>): void;
  done(status: number, fields?: Record<string, unknown>): void;
}

export function makeLogger(req: Request, handler: string): Logger {
  const requestId =
    req.headers.get('x-vercel-id') ||
    req.headers.get('x-request-id') ||
    crypto.randomUUID();
  const startedAt = performance.now();
  const ip =
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
    req.headers.get('x-real-ip') ||
    'unknown';
  const base = { handler, request_id: requestId, ip };

  function emit(level: 'info' | 'error', kind: string, fields?: Record<string, unknown>) {
    const line = { level, kind, ...base, ...fields };
    if (level === 'error') {
      console.error(JSON.stringify(line));
    } else {
      console.log(JSON.stringify(line));
    }
  }

  return {
    event(kind, fields) {
      emit('info', kind, fields);
    },
    error(kind, fields) {
      emit('error', kind, fields);
    },
    done(status, fields) {
      const latencyMs = Math.round(performance.now() - startedAt);
      emit('info', 'request_done', { status, latency_ms: latencyMs, ...(fields ?? {}) });
    },
  };
}
