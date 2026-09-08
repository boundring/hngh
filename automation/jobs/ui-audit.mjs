#!/usr/bin/env node
// ui-audit — programmatic legibility/contrast audit of the served dashboard.
// Community-standard base: axe-core (the accessibility standard) driven by
// puppeteer-core on the system Chrome. Register rules implement
// display-register-spec §7 (text-legibility floor + name completeness) and
// the Winamp floor: density allowed, illegibility never. Findings land in
// the hngh report ledger with per-rule dedup identities; telemetry records
// the run. Fail-closed: any harness fault files one alert and exits 0 —
// an audit never fails a tick.
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const require = createRequire(import.meta.url);
const AUTO = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const KERNEL = process.env.HNGH_HOME || path.join(process.env.HOME, 'Projects/etc/hngh');
const BASE = process.env.DASH_URL || 'http://127.0.0.1:8890';
const RQ = path.join(KERNEL, 'scripts', 'report-queue');
const TELEMETRY = path.join(AUTO, 'jobs', 'telemetry.py');

function ledger(kind, text, identity) {
  try {
    // reports.md rows are pipe-delimited: keep the breadcrumb convention
    // (breadcrumbs.sh) — pipes in text become ¦ so the row stays parseable.
    execFileSync('python3', [RQ, '--add', kind,
      String(text).replace(/\|/g, '¦'), '--identity', identity,
      '--window', '86400'],
      { env: { ...process.env, HNGH_REPORT_ROOT: KERNEL }, stdio: 'ignore' });
  } catch { /* fail-closed: a ledger fault never fails the audit */ }
}

function telemetry(wallS, summary) {
  try {
    execFileSync('python3', [TELEMETRY, 'emit', '--kind', 'ui-audit',
      '--source', 'ui-audit', '--wall-s', String(wallS),
      '--subject', 'dashboard legibility audit', '--body', summary],
      { stdio: 'ignore' });
  } catch { /* best-effort by design */ }
}

const t0 = Date.now();
const violations = [];
let note = '';
try {
  const puppeteer = require('puppeteer-core');
  const axeSource = readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8');
  const browser = await puppeteer.launch({
    executablePath: process.env.CHROME_BIN || '/usr/bin/google-chrome-stable',
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--window-size=1440,1000'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 1000 });
  await page.goto(BASE + '/', { waitUntil: 'networkidle2', timeout: 30000 });
  // schedule is the default-open tab; activate anyway (idempotent) so the
  // lazy view init has definitely run before measuring.
  await page.click('#tab-schedule').catch(() => {});
  await page.waitForSelector('#p-schedule .glabel-row .gname', { timeout: 30000 });
  await new Promise((r) => setTimeout(r, 800)); // first paint settle

  // rule: winamp is home — first visit (empty storage) must land on it
  const theme = await page.evaluate(() => document.documentElement.dataset.theme || '(none)');
  if (theme !== 'winamp') {
    violations.push({ rule: 'default-theme-winamp', example: 'data-theme=' + theme });
  }

  // community standard: full axe-core scan
  await page.evaluate(axeSource);
  const axe = await page.evaluate(() => axe.run(document, { resultTypes: ['violations'] }));
  for (const v of axe.violations || []) {
    violations.push({
      rule: 'axe:' + v.id,
      example: (v.nodes || []).slice(0, 3).map((n) => n.target.join(' ')).join(' | '),
    });
  }

  // register rules: text-legibility floor + name completeness
  const rows = await page.evaluate(() => {
    // squash is a property of the fixed-height ROW (does its box clip its
    // text?), not of inline spans whose line-box metrics always "overflow".
    const squashed = Array.from(document.querySelectorAll(
      '#p-schedule .glabel-row:not(.glabel-head)'))
      .filter((el) => el.scrollHeight > el.clientHeight + 2)
      .map((el) => 'row: ' + ((el.querySelector('.gname') || {}).textContent || '?'));
    const els = Array.from(document.querySelectorAll(
      '#p-schedule .gname, #p-schedule .gest, #p-schedule [class*="gchip"]'
    )).map((el) => {
      const cs = getComputedStyle(el);
      return {
        cls: String(el.className),
        text: (el.textContent || '').trim().slice(0, 90),
        clip: el.scrollWidth > el.clientWidth + 2,
        squash: el.scrollHeight > el.clientHeight + 2,
        fs: parseFloat(cs.fontSize),
        titled: !!el.closest('[title]'),
      };
    });
    return { els, squashed };
  });
  // name-completeness: every feed name must appear in the rendered tab.
  // Names and corpus must be measured at the same instant, inside the
  // page: a separate node-side feed fetch can observe a regen the page
  // has not fetched yet and file phantom violations. Every historical
  // firing matches that shape — a one-shot at the first tick after a
  // feed-content change (2026-08-29/09-01/09-02 12:00 queue refreshes,
  // 2026-09-06 21:00: the four drop-ins committed 20:42–20:54), zero
  // violations on every stable-feed run before and since.
  const schedInPage = () => page.evaluate(async () => {
    const j = await (await fetch('schedule.json')).json();
    const names = [...(j.recurring || []).map((r) => r.name),
                   ...(j.oneoff || []).map((o) => o.name)];
    const corpus = document.body.innerText + '\n' +
      Array.from(document.querySelectorAll('#p-schedule [title]'))
        .map((e) => e.getAttribute('title')).join('\n') + '\n' +
     Array.from(document.querySelectorAll('#p-schedule [data-tip]'))
        .map((e) => e.getAttribute('data-tip')).join('\n');
    return { names, corpus };
  });
  let m = await schedInPage();
  let missing = m.names.filter((n) => n && !m.corpus.includes(n));
  if (missing.length > 0) {
    // reconcile once: the page may render a feed older than the feed read
    // — force a re-fetch + re-render, settle, then re-measure both sides
    // at the same instant before filing.
    await page.evaluate(() =>
      window.ScheduleView && window.ScheduleView.refresh()).catch(() => {});
    await new Promise((r) => setTimeout(r, 2000));
    m = await schedInPage();
    missing = m.names.filter((n) => n && !m.corpus.includes(n));
  }
  for (const n of missing) {
    violations.push({ rule: 'name-completeness', example: n });
  }
  for (const s of rows.squashed) {
    violations.push({ rule: 'text-legibility-squash', example: s });
  }
  for (const el of rows.els) {
    if (el.clip && !el.titled) {
      violations.push({ rule: 'text-legibility-clip', example: el.cls + ': ' + el.text });
    }
    if (el.fs < 10) {
      violations.push({ rule: 'font-floor', example: el.cls + ' @ ' + el.fs + 'px' });
    }
  }

  await page.screenshot({ path: '/tmp/hngh-ui-audit.png' });
  await browser.close();
  note = 'checked: axe, clip, squash, font-floor, name-completeness, default-theme-winamp';
} catch (err) {
  ledger('alert', 'ui-audit unavailable: ' + (err && err.message ? err.message : err),
    'ui-audit:unavailable');
  telemetry((Date.now() - t0) / 1000, 'unavailable: ' + (err && err.message));
  console.log('ui-audit: unavailable — filed alert, exit 0');
  process.exit(0);
}

const wallS = (Date.now() - t0) / 1000;
const byRule = {};
for (const v of violations) (byRule[v.rule] = byRule[v.rule] || []).push(v.example);
for (const [rule, exs] of Object.entries(byRule)) {
  ledger('alert',
    'ui-audit ' + rule + ': ' + exs.length + ' violation(s) — ' + exs.slice(0, 3).join(' | '),
    'ui-audit:' + rule);
}
const summary = violations.length + ' violation(s) across ' +
  Object.keys(byRule).length + ' rule(s); ' + note;
telemetry(wallS, summary);
console.log('ui-audit: ' + summary + ' — exit 0');
process.exit(0);
