#!/usr/bin/env node
// render-blocks.mjs — structured render-block transport for the jcode
// worker lane (viz-transport slice, 2026-09-14).
//
// Purpose: let worker.mjs optionally emit machine-parseable render blocks
// for a dashboard consumer WITHOUT breaking the plain-text stdout contract
// (lib/causes.sh classifies the log as model text).
//
// Two transports, both opt-in and off by default:
//   1. Marker-delimited stdout section (works through shell redirection,
//      which drops extra fds): the worker appends
//        HNGH-RENDER-BEGIN
//        <one JSON envelope per line>
//        HNGH-RENDER-END
//      after the turn text. parseRenderSection() strips it back out.
//   2. JSON side-channel on an extra fd (default fd 3): one JSON envelope
//      per line via writeSideChannel(). Survives even when a consumer
//      wants stdout to stay byte-identical to the model text.
//
// Envelope schema (version 1):
//   {"v":1,"kind":"turn-render","blocks":[...],"tools":[...],"usage":{...}}
// where each block is {"kind":string,"payload":string} extracted from
// fenced ```hngh-render <kind> ... ``` sections in the turn text.
// Unknown, malformed, or duplicate input fails closed: the extractor
// never throws on model text; unparsable envelopes return {ok:false}.

export const RENDER_BEGIN = "HNGH-RENDER-BEGIN";
export const RENDER_END = "HNGH-RENDER-END";
export const RENDER_FENCE = "hngh-render";

import { writeSync } from "node:fs";

// Extract render blocks from turn text. A block is a fenced section:
//
//   ```hngh-render <kind>
//   <payload lines>
//   ```
//
// kind is the first word after the fence info string (default "raw").
// Unclosed fences are ignored (fail closed: no partial block emitted).
// Never throws: on non-string input returns [].
export function extractRenderBlocks(text) {
  if (typeof text !== "string") return [];
  const blocks = [];
  const seen = new Set();
  const lines = text.split("\n");
  let open = null; // {kind, payload[]}
  for (const line of lines) {
    const t = line.trim();
    if (open === null) {
      const m = /^```\s*hngh-render(?:\s+(\S+))?\s*$/.exec(t);
      if (m) open = { kind: m[1] || "raw", payload: [] };
    } else if (/^```\s*$/.test(t)) {
      const payload = open.payload.join("\n");
      const key = `${open.kind}\0${payload}`;
      if (!seen.has(key)) {
        seen.add(key);
        blocks.push({ kind: open.kind, payload });
      }
      open = null;
    } else {
      open.payload.push(line);
    }
  }
  // Unclosed fence: dropped (fail closed).
  return blocks;
}

// Build the v1 envelope for a turn. turn is {text, toolCalls, usage}
// as returned by the SDK; missing fields degrade to empty/omitted.
export function buildEnvelope(turn) {
  const t = turn && typeof turn === "object" ? turn : {};
  const env = {
    v: 1,
    kind: "turn-render",
    blocks: extractRenderBlocks(t.text),
    tools: Array.isArray(t.toolCalls)
      ? t.toolCalls.map((c) => ({ name: String(c.name || ""), error: c.error ? String(c.error) : "" }))
      : [],
  };
  if (t.usage && typeof t.usage === "object") {
    env.usage = {
      input: Number(t.usage.input || 0),
      output: Number(t.usage.output || 0),
    };
  }
  return env;
}

// Format the marker-delimited stdout section for an envelope.
// One JSON object per line inside the markers (currently one line).
export function formatRenderSection(envelope) {
  return `\n${RENDER_BEGIN}\n${JSON.stringify(envelope)}\n${RENDER_END}\n`;
}

// Parse a log that may carry a trailing render section. Returns
// {text, envelopes} where text is the log with sections stripped and
// envelopes is the array of parsed envelope objects. Malformed JSON
// inside markers fails closed: the section is stripped and recorded
// as {ok:false, raw} rather than thrown.
export function parseRenderSection(log) {
  if (typeof log !== "string") return { text: "", envelopes: [] };
  const envelopes = [];
  const out = [];
  const lines = log.split("\n");
  let i = 0;
  while (i < lines.length) {
    if (lines[i].trim() === RENDER_BEGIN) {
      i += 1;
      const raw = [];
      while (i < lines.length && lines[i].trim() !== RENDER_END) {
        raw.push(lines[i]);
        i += 1;
      }
      const closed = i < lines.length && lines[i].trim() === RENDER_END;
      if (closed) {
        for (const r of raw) {
          if (!r.trim()) continue;
          try {
            const obj = JSON.parse(r);
            if (obj && obj.v === 1 && obj.kind === "turn-render") envelopes.push(obj);
            else envelopes.push({ ok: false, raw: r });
          } catch {
            envelopes.push({ ok: false, raw: r });
          }
        }
        i += 1; // consume END
      } else {
        // Unclosed section: keep the raw lines as text (fail closed).
        out.push(RENDER_BEGIN, ...raw);
      }
    } else {
      out.push(lines[i]);
      i += 1;
    }
  }
  return { text: out.join("\n"), envelopes };
}

// Write one JSON envelope line to an extra fd (default 3). Returns true
// on success, false when the fd is not open or the write fails — the
// caller must treat false as "side-channel unavailable", never as fatal.
export function writeSideChannel(envelope, fd = 3) {
  try {
    writeSync(fd, JSON.stringify(envelope) + "\n");
    return true;
  } catch {
    return false;
  }
}
