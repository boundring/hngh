/* hngh-automation · nervous-system dashboard app
   Pure reader over dashboard/data.json (digest spine) with the
   `dashboard-readout --json` spine (verdict/queue/etas/roster) as source.

   One panel per tab (Camp=overview | Schedule | Sessions | System |
   Research | Logs | KB); the header strip always shows the spine verdict +
   counts. Camp is the landing view; Logs hosts the operator-items feed plus
   the Reports|Digest sub-toggle. The page makes no governance input —
   fetch-and-render only. */
(function () {
  'use strict';

  var REFRESH_MS = 10000;      // 10s auto-refresh
  var STALE_MS = 5 * 60 * 1000; // >5 min => stale beacon

  var $ = function (id) { return document.getElementById(id); };

  // ---------- shared poll helper (B3) ----------
  // One wrapper every view's timer goes through: paused entirely while the
  // tab is hidden (visibilitychange), exponential backoff after a failed
  // poll (interval x2, capped at 60s), reset on success. fn returns a
  // promise (or nothing); a rejection/throw counts as the failed fetch.
  window.HnghPoll = {
    start: function (fn, opts) {
      var base = (opts && opts.interval) || REFRESH_MS;
      var delay = base, t = null;
      function clear() { if (t) { clearTimeout(t); t = null; } }
      function schedule(ms) { clear(); t = setTimeout(tick, ms); }
      function tick() {
        if (document.hidden) return; // paused while hidden
        var r = null;
        try { r = fn(); } catch (e) { /* treated as failure below */ }
        Promise.resolve(r).then(function () {
          delay = base; schedule(delay);
        }, function () {
          delay = Math.min(delay * 2, 60000); schedule(delay);
        });
      }
      document.addEventListener('visibilitychange', function () {
        if (document.hidden) clear();
        else tick(); // resume immediately on visible
      });
      tick(); // first poll immediate
      return { stop: clear };
    }
  };

  // ---------- token plumbing (P1 server contract) ----------
  // Every mutating POST the UI makes carries X-Hngh-Token, read from the
  // <meta name="hngh-token"> tag the server injects into the served
  // index.html. A 403 means this page predates the running server's
  // token: an inline "session expired — reload" chip, never a silent
  // failure.
  function hnghToken() {
    var m = document.querySelector('meta[name="hngh-token"]');
    return m ? (m.getAttribute('content') || '') : '';
  }
  function tokenExpiredChip() {
    if (document.getElementById('hngh-expired')) return;
    var d = document.createElement('div');
    d.id = 'hngh-expired';
    d.style.cssText = 'position:fixed;right:10px;bottom:10px;z-index:99;' +
      'background:var(--panel);color:var(--warn);border:1px solid var(--warn);' +
      'padding:6px 10px;font-size:12px';
    d.innerHTML = 'session expired — <button class="ghost" id="hngh-expired-reload">reload</button>';
    document.body.appendChild(d);
    document.getElementById('hngh-expired-reload').addEventListener('click', function () {
      location.reload();
    });
  }
  // POST with the token header; resolves the parsed body even on non-2xx
  // callers may want the server's honest error text, but 403 always
  // surfaces the expired chip.
  function postJson(url, body, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 8000);
    return fetch(url, {
      method: 'POST', cache: 'no-store', signal: ctrl.signal,
      headers: { 'Content-Type': 'application/json', 'X-Hngh-Token': hnghToken() },
      body: JSON.stringify(body || {})
    }).then(function (r) {
      clearTimeout(t);
      if (r.status === 403) tokenExpiredChip();
      return r.json().catch(function () { return {}; }).then(function (j) {
        if (!r.ok) throw new Error(j.error || ('HTTP ' + r.status));
        return j;
      });
    }).catch(function (e) { clearTimeout(t); throw e; });
  }

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtAge(sec) {
    if (sec == null || isNaN(sec)) return '';
    if (sec < 90) return Math.round(sec) + 's';
    var m = sec / 60;
    if (m < 90) return Math.round(m) + 'm';
    var h = m / 60;
    if (h < 48) return (Math.round(h * 10) / 10) + 'h';
    return Math.round(h / 24) + 'd';
  }
  function ago(ts) {
    var t = Date.parse(ts);
    if (isNaN(t)) return ts;
    return fmtAge((Date.now() - t) / 1000) + ' ago';
  }
  function ageChip(ts) {
    var t = Date.parse(ts);
    if (isNaN(t)) return '';
    var s = (Date.now() - t) / 1000;
    var cls = s < 3600 ? 'fresh' : (s < 86400 ? 'aging' : 'stale');
    return '<span class="agechip ' + cls + '" title="' + esc(ts) + '">' + fmtAge(s) + '</span>';
  }

  // ---------- operator items (open -> handled -> dismissed) ----------
  // Lifecycle state over dashboard/operator-items.json (feed) plus the
  // server-side dismissal ledger dashboard/operator-dismissed.json. Display
  // only; a dismissal never feeds governance. Falls back to the legacy plain
  // digest bullets when the feed is unavailable.
  var opState = { items: null, dismissed: {}, approved: {} };
  var lastRender = {};
  function fetchOpState() {
    return Promise.all([
      fetchJson('operator-items.json').catch(function () { return null; }),
      fetchJson('operator-dismissed.json').catch(function () { return null; }),
      fetchJson('operator-approved.json').catch(function () { return null; })
    ]).then(function (r) {
      if (r[0] && Array.isArray(r[0].items)) opState.items = r[0].items;
      if (r[1] && r[1].dismissed) {
        opState.dismissed = r[1].dismissed;
      }
      if (r[2] && r[2].approved) {
        opState.approved = r[2].approved;
        // approved == handled even before the feed rebuilds (the feed
        // reads the same ledger): Camp's open/handled split and the
        // per-item controls both read it.status directly.
        (opState.items || []).forEach(function (it) {
          if (it && opState.approved[it.id]) it.status = 'handled';
        });
      }
      // stale-arm revalidation (ux-review dashboard-logs:2): an arm only
      // survives a fetch while its item is still live — the same live
      // predicate the render uses; never cleared on every fetch, a poll
      // would kill the two-click confirm mid-flow.
      if (armedId && opState.items &&
          !opState.items.some(function (it) {
            return it && it.id === armedId && !opState.dismissed[it.id];
          })) {
        armedId = null;
      }
      if (armedHandle && opState.items &&
          !opState.items.some(function (it) {
            return it && it.id === armedHandle && it.status !== 'handled';
          })) {
        armedHandle = null;
      }
      return opState;
    });
  }
  function dismissedToday() {
    var today = new Date().toISOString().slice(0, 10);
    return Object.keys(opState.dismissed).filter(function (id) {
      return String(opState.dismissed[id] || '').slice(0, 10) === today;
    }).length;
  }
  // open (not handled, not dismissed) feed items — folded into the header attention count
  function openOpCount() {
    if (!opState.items) return 0;
    return opState.items.filter(function (it) {
      return it && it.id && it.status !== 'handled' && !opState.dismissed[it.id];
    }).length;
  }

  // header + logs re-render once the operator-items feed lands (or an item is
  // dismissed): the attention count and verdict pill depend on opState.
  function rerenderWithOpState() {
    if (lastRender.d === undefined) return;
    if (lastRender.res) renderHeader(lastRender.d, lastRender.spine, lastRender.res);
    renderLogs(lastRender.d, lastRender.spine, lastRender.res);
  }
  // views that show op items beyond Logs (Camp/overview) register here and
  // are re-rendered whenever op state or armed-dismiss state changes.
  var opRerenders = [];
  function rerenderOp() {
    if (lastRender.d === undefined) { opRerenders.forEach(function (fn) { fn(); }); return; }
    renderLogs(lastRender.d, lastRender.spine, lastRender.res); // notifies opRerenders
  }
  var armedId = null; // item whose dismiss is armed, awaiting the inline confirm
  var armedHandle = null; // item whose handle is armed, awaiting the inline confirm
  function operatorItemsHtml(filter) {
    // filter: optional predicate over live items — Camp shows open/handled
    // separately; null (Logs) renders the full live list + counters.
    var items = opState.items;
    if (!items) { // feed unavailable -> legacy digest bullets
      var ops = parseOperators(lastRender.d && lastRender.d.digest);
      return {
        count: ops.length,
        open: ops.length,
        feed: false,
        counter: '',
        html: ops.length
          ? '<ol>' + ops.map(function (l) { return '<li>' + esc(l) + '</li>'; }).join('') + '</ol>'
          : '<span class="ok-note">nothing flagged for the operator</span>'
      };
    }
    var live = items.filter(function (it) { return it && it.id && !opState.dismissed[it.id]; });
    var shown = filter ? live.filter(filter) : live;
    var rows = shown.map(function (it) {
      var handled = it.status === 'handled';
      // honest dismiss: arm first ("dismiss? yes/no" inline), confirm second —
      // the old hover-title-only "removes for good" warning is gone, because
      // it was false: recurring items are re-emitted by their source.
      // handle is offered only while open (the two-click arm mirrors
      // dismiss); dismiss stays available on the handled side so
      // open -> handled -> dismissed works per item too.
      var ctl = '';
      if (!handled) {
        ctl += armedHandle === it.id
          ? '<span class="oparm">handle? ' +
            '<button class="ghost" data-handle-yes="' + esc(it.id) + '">yes</button>' +
            '<button class="ghost" data-handle-no="' + esc(it.id) + '">no</button></span>'
          : '<button class="ghost" data-handle="' + esc(it.id) + '" ' +
            'title="mark handled - done with this item; it leaves the open list">handle</button>';
      }
      ctl += armedId === it.id
        ? '<span class="oparm">dismiss? ' +
          '<button class="ghost" data-dismiss-yes="' + esc(it.id) + '">yes</button>' +
          '<button class="ghost" data-dismiss-no="' + esc(it.id) + '">no</button></span>'
        : '<button class="ghost" data-dismiss="' + esc(it.id) + '" ' +
          'title="mark viewed — hides the item; recurring items return until their source stops emitting them">dismiss</button>';
      return '<div class="opitem">' +
        (handled
          ? '<span class="opstat"><i class="sw green"></i>✓ handled</span>'
          : '<span class="opstat"><i class="sw amber"></i>open</span>') +
        (it.first_seen ? ageChip(it.first_seen) : '') +
        (it.recurring
          ? '<span class="opstat" title="recurring items return until their source stops emitting them">↻ recurring</span>'
          : '') +
        '<span class="optext">' + esc(it.text) + '</span>' +
        (handled && it.evidence ? '<span class="opev dim">' + esc(it.evidence) + '</span>' : '') +
        ctl +
        '</div>';
    }).join('');
    var gone = Object.keys(opState.dismissed).length;
    var counter = '';
    if (!filter) {
      if (gone) counter += '<span class="dim"> dismissed today: ' + dismissedToday() + '</span>';
      if (live.some(function (it) { return it.status === 'handled'; }))
        counter += ' <button class="ghost" data-dismiss-all' +
          ' title="dismiss every handled item (one POST per item)">dismiss all handled</button>';
      if (live.some(function (it) { return it.recurring; }))
        counter += '<span class="dim"> recurring items return until their source stops emitting them</span>';
    }
    return {
      count: live.length,
      open: live.filter(function (it) { return it.status !== 'handled'; }).length,
      feed: true,
      counter: counter,
      html: shown.length ? rows
        : (filter ? '' : '<span class="ok-note">nothing flagged for the operator</span>')
    };
  }
  function postDismissRaw(id) {
    return postJson('/operator-item/dismiss', { id: id }).then(function () {
      opState.dismissed[id] = new Date().toISOString();
    });
  }
  function confirmDismiss(id) {
    armedId = null;
    postDismissRaw(id).then(rerenderOp).catch(rerenderOp);
  }
  function postHandleRaw(id) {
    return postJson('/operator-item/handle', { id: id }).then(function () {
      opState.approved[id] = new Date().toISOString();
      // normalize the cached feed row: Camp splits open/handled on
      // it.status, and the feed only reflects the approval ledger on
      // its next rebuild.
      (opState.items || []).forEach(function (it) {
        if (it && it.id === id) it.status = 'handled';
      });
    });
  }
  function confirmHandle(id) {
    armedHandle = null;
    postHandleRaw(id).then(rerenderOp).catch(rerenderOp);
  }
  function dismissAllHandled() {
    var targets = (opState.items || []).filter(function (it) {
      return it && it.id && it.status === 'handled' && !opState.dismissed[it.id];
    });
    if (!targets.length) return;
    var chain = Promise.resolve();
    targets.forEach(function (it) {
      chain = chain.then(function () { return postDismissRaw(it.id); });
    });
    chain.then(function () { armedId = null; rerenderOp(); }).catch(rerenderOp);
  }
  // one delegated handler for every op-item dismiss control, wherever it
  // renders (Logs #logs-ops, Camp #overview-root).
  document.addEventListener('click', function (e) {
    var b;
    if ((b = e.target.closest('[data-dismiss]'))) {
      armedId = b.getAttribute('data-dismiss');
      armedHandle = null;
      rerenderOp();
    } else if ((b = e.target.closest('[data-dismiss-no]'))) {
      armedId = null;
      rerenderOp();
    } else if ((b = e.target.closest('[data-dismiss-yes]'))) {
      confirmDismiss(b.getAttribute('data-dismiss-yes'));
    } else if ((b = e.target.closest('[data-handle]'))) {
      armedHandle = b.getAttribute('data-handle');
      armedId = null;
      rerenderOp();
    } else if ((b = e.target.closest('[data-handle-no]'))) {
      armedHandle = null;
      rerenderOp();
    } else if ((b = e.target.closest('[data-handle-yes]'))) {
      confirmHandle(b.getAttribute('data-handle-yes'));
    } else if (e.target.closest('[data-dismiss-all]')) {
      dismissAllHandled();
    } else if ((b = e.target.closest('[data-markread]'))) {
      postJson('/report-queue/mark-read', { id: b.getAttribute('data-markread') })
        .then(fetchQueue)
        .catch(function (e) {
          // failures surface inline, never silently: the Sep-12 stale-server
          // incident made 76 clicks invisible. 403 still rides the expired
          // chip from postJson; this note covers 404/400/500/network.
          rqState.error = String((e && e.message) || e);
          renderQueue();
        });
    }
  });
  // ---- health verdict over the digest text (pure reader, no dates invented) ----
  function digestVerdict(txt) {
    if (!txt) return { level: 'none', label: 'no digest' };
    var t = txt.toLowerCase();
    // Judge only the report body, not the "For the operator" notes (those are
    // forward work items — e.g. pre-existing out-of-scope failures — not a red
    // health signal for the collection itself).
    var op = t.indexOf('for the operator');
    if (op > 0) t = t.slice(0, op);
    // Honor the digest author's own verdict ("all green", "verdict healthy",
    // "no repairs needed") instead of word-scanning ambiguous tokens like
    // "none failed" or a model that already failed earlier in the report.
    var hard = /needs attention|critical|outage|not healthy|(?:needs|requires?)\s+repair/i.test(t);
    if (hard) return { level: 'warn', label: 'Needs attention' };
    var positive = /all(?:-?\s?)?(?:clear|green|good)|\bhealthy\b|no repairs? (?:needed|required)|nothing (?:new|broken|needs you)/i.test(t);
    var red = /failed|failure|\berror\b|red flag/i.test(t);
    return (!red || positive)
      ? { level: 'ok', label: 'All clear' }
      : { level: 'warn', label: 'Needs attention' };
  }
  // extract the "For the operator" bullet block from the digest markdown
  function parseOperators(txt) {
    if (!txt) return [];
    var i = txt.toLowerCase().indexOf('for the operator');
    if (i < 0) return [];
    var sec = txt.slice(i);
    // stop at the next markdown heading
    var next = sec.search(/\n#{1,3}\s+\S/);
    if (next > 0) sec = sec.slice(0, next);
    var lines = sec.split('\n')
      .map(function (l) { return l.trim(); })
      .filter(function (l) { return /^\d+\./.test(l) || /^\* /.test(l) || /^-\s+/.test(l); });
    if (lines.length && lines[0].toLowerCase().indexOf('for the operator') === 0) lines.shift();
    return lines.map(function (l) { return l.replace(/\*\*/g, '').trim(); })
      .filter(function (l) { return /[a-z0-9]/i.test(l); });
  }

  // ---------- data sources ----------
  function fetchJson(url, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 8000);
    return fetch(url, { cache: 'no-store', signal: ctrl.signal })
      .then(function (r) { clearTimeout(t); if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
      .catch(function (e) { clearTimeout(t); throw e; });
  }
  function fetchText(url, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 8000);
    return fetch(url, { cache: 'no-store', signal: ctrl.signal })
      .then(function (r) { clearTimeout(t); if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
      .catch(function (e) { clearTimeout(t); throw e; });
  }

  // ---------- report-queue read state (B8) ----------
  // Unread rows derive client-side from the ledger mirror served into
  // dashboard/ (reports.md + report-cursor): a row is unread when it
  // follows the cursor id in file order — the same fail-open rule as
  // scripts/report-queue unread_rows (unknown cursor => all unread).
  // mark-read advances the operator's own reading cursor via the
  // token-guarded POST; --prune stays CLI-only (destructive).
  var rqState = { rows: [], unread: [], live: false, error: null };
  function parseReportRows(txt) {
    var rows = [];
    String(txt || '').split('\n').forEach(function (l) {
      l = l.trim();
      if (!/^\|.*\|$/.test(l)) return;
      var c = l.slice(1, -1).split('|').map(function (s) { return s.trim(); });
      if (c.length === 5 && c[0] !== 'timestamp')
        rows.push({ ts: c[0], kind: c[1], id: c[2], first: c[3] });
    });
    return rows; // file order = oldest first, same as the ledger
  }
  function fetchQueue() {
    return Promise.all([
      fetchText('reports.md').catch(function () { return null; }),
      fetchText('report-cursor').catch(function () { return ''; })
    ]).then(function (r) {
      if (r[0] == null) throw new Error('reports.md unavailable');
      var rows = parseReportRows(r[0]);
      var cid = (r[1] || '').trim();
      var idx = -1;
      for (var i = 0; i < rows.length; i++) if (rows[i].id === cid) idx = i;
      rqState.rows = rows;
      // unknown cursor id fails open: nothing silently hidden by a stale cursor
      rqState.unread = idx >= 0 ? rows.slice(idx + 1) : rows.slice();
      rqState.live = true;
      rqState.error = null; // a successful fetch clears any stale failure note
      renderQueue();
    }).catch(function () {
      var was = rqState.live;
      rqState.live = false; rqState.unread = [];
      if (was) renderQueue();
    });
  }
  function renderQueue() {
    var el = $('logs-queue');
    if (!el) return;
    if (!rqState.live) {
      el.innerHTML = '<span class="ops-title">Report queue</span>' +
        '<span class="dim"> ledger mirror unavailable — read state CLI-only</span>';
      return;
    }
    var u = rqState.unread;
    var rows = u.slice(-10).reverse().map(function (r) { // newest first
      return '<div class="opitem rqrow">' +
        '<span class="agechip aging" title="' + esc(r.ts) + '">' + esc(r.kind) + '</span>' +
        '<span class="optext" title="' + esc(r.first) + '">' + esc(r.first) + '</span>' +
        '<button class="ghost" data-markread="' + esc(r.id) +
        '" title="advance the reading cursor past this report (POST /report-queue/mark-read)">mark read</button>' +
        '</div>';
    }).join('');
    el.innerHTML = '<span class="ops-title">Report queue <span class="dim">' +
      (u.length ? u.length + ' unread report' + (u.length === 1 ? '' : 's') : 'all read') +
      (rqState.error ? ' — mark-read failed: ' + esc(rqState.error) : '') +
      '</span></span>' + (u.length ? rows : '<span class="ok-note">no unread reports</span>');
  }

  // ---------- header strip (verdict + spine counts, always visible) ----------
  function verdictOf(d, spine) {
    var v = spine && spine.verdict;
    if (v && v.state) {
      var s = String(v.state);
      var ok = /clear|green|healthy|ok/i.test(s);
      var unknown = /none|unknown/i.test(s);
      return {
        level: ok ? 'ok' : (unknown ? 'none' : 'warn'),
        label: s.replace(/[-_]+/g, ' '),
        reasons: v.reasons || []
      };
    }
    // legacy fallback: derive from the digest text when the spine carries no verdict
    var dv = digestVerdict(d ? d.digest : '');
    return { level: dv.level, label: dv.label, reasons: [] };
  }
  function renderHeader(d, spine, res) {
    var v = verdictOf(d, spine);
    var openOp = openOpCount();
    if (openOp > 0) {
      v.level = 'warn';
      v.label = 'Needs attention';
      v.reasons = v.reasons.concat([openOp + ' open operator item' + (openOp === 1 ? '' : 's')]);
    }
    var pill = $('verdict-pill');
    pill.className = 'strip-verdict ' + v.level;
    pill.textContent = v.label;
    pill.title = v.reasons.length ? 'verdict reasons: ' + v.reasons.join(' · ') : '';
    var queue = spine ? spine.queue : [];
    var due = queue.filter(function (i) { return i.status && i.status !== 'done'; }).length;
    var roster = spine ? spine.roster : [];
    var activeAgents = roster.filter(function (a) {
      var st = String(a.state || '').toLowerCase();
      return st === 'working' || st === 'running' || st === 'active';
    }).length;
    var crumbs = (d && d.breadcrumbs) || [];
    var attn = crumbs.filter(function (c) { return /CRITICAL|NOTABLE|alert|failure/i.test(c.event || ''); }).length + openOp;
    var runs = (d && Number(d.hngh_runs)) || roster.length || '—';
    $('c-runs').textContent = runs;
    $('c-queued').textContent = due;
    $('c-agents').textContent = activeAgents;
    $('c-attention').textContent = attn;
    $('cnt-attention').classList.toggle('hot', attn > 0);
    var tick = $('lcd-ticker-text');
    if (tick) tick.textContent = v.label +
      (v.reasons.length ? ' — ' + v.reasons.join(' · ') : '') +
      ' · ' + due + ' queued · ' + activeAgents + ' agents at work';
    setBeacon(res.fresh);
    setMeta(res.generated, res.source, res.note);
    // B13: title badge mirrors the attention count
    document.title = openOp > 0 ? '(' + openOp + ') hngh' : 'hngh';
  }
  function headerNoSignal(msg) {
    var pill = $('verdict-pill');
    pill.className = 'strip-verdict none';
    pill.textContent = 'no signal';
    pill.title = msg || '';
    ['c-runs', 'c-queued', 'c-agents', 'c-attention'].forEach(function (id) {
      $(id).textContent = '—';
    });
    $('cnt-attention').classList.remove('hot');
  }

  // ---------- logs tab: operator items + Reports|Digest sub-toggle ----------
  // Facet state (logs-page-spec §4) filters ONLY fields the feed really
  // carries — event, job, detail text. The feed has no severity field yet
  // (§3), so no severity chips and no row-class change until it lands:
  // crumbClass stays the existing display approximation. No facet state
  // leaves the page — display only.
  var facet = { event: '', job: '', text: '' };
  var curCrumbs = [], lastOpCount = 0, lastDigestLines = 0;
  function facetActive() { return !!(facet.event || facet.job || facet.text); }
  function crumbClass(ev) {
    return /CRITICAL|alert|failure/i.test(ev) ? 'alert'
      : (/NOTABLE|steer|done/i.test(ev) ? 'notable' : '');
  }
  function visibleRows() {
    var t = facet.text.toLowerCase();
    return curCrumbs.slice().reverse().filter(function (c) { // newest first
      if (facet.event && (c.event || '(none)') !== facet.event) return false;
      if (facet.job && (c.job || '(none)') !== facet.job) return false;
      if (t && String(c.detail || '').toLowerCase().indexOf(t) < 0) return false;
      return true;
    });
  }
  function crumbRow(c) {
    var ev = c.event || '';
    return '<div class="crumb ' + crumbClass(ev) + '">' +
      ageChip(c.ts) +
      '<span class="cts">' + esc(c.ts) + '</span>' +
      '<span class="cjob">' + esc(c.job) + '</span>' +
      '<span class="cevent">' + esc(ev) + '</span>' +
      '<span class="cdetail" title="' + esc(c.detail) + '">' + esc(c.detail) + '</span>' +
      '</div>';
  }
  // §5 slices, not lines: rows grouped by job into collapsible groups; the
  // header is the slice (job, row count, worst severity), rows are the
  // drill-down. Groups ordered by their newest row; alert groups open.
  function renderCrumbRows() {
    var body = $('logs-rows');
    var vis = visibleRows();
    if (!vis.length) {
      body.innerHTML = '<div class="ok-note">' +
        (curCrumbs.length ? 'no entries match the active filters' : 'no reports') + '</div>';
      return;
    }
    var order = [], groups = {};
    vis.forEach(function (c) {
      var jb = c.job || '(none)';
      if (!groups[jb]) { groups[jb] = []; order.push(jb); }
      groups[jb].push(c);
    });
    body.innerHTML = order.map(function (jb) {
      var rows = groups[jb];
      var worst = '';
      rows.forEach(function (c) {
        var cl = crumbClass(c.event || '');
        if (cl === 'alert' || (cl === 'notable' && worst !== 'alert')) worst = cl;
      });
      return '<details class="crumb-group"' + (worst === 'alert' ? ' open' : '') + '>' +
        '<summary><span class="cg-job">' + esc(jb) + '</span>' +
        '<span class="cg-count">' + rows.length + '</span>' +
        (worst ? '<span class="cg-sev ' + worst + '">' + worst + '</span>' : '') +
        '</summary>' + rows.map(crumbRow).join('') + '</details>';
    }).join('');
  }
  function logsSum() {
    var vis = visibleRows(), attn = 0;
    vis.forEach(function (c) { if (crumbClass(c.event || '')) attn++; });
    $('logs-sum').textContent =
      lastOpCount + ' operator item' + (lastOpCount === 1 ? '' : 's') +
      ' · ' + vis.length + ' of ' + curCrumbs.length + ' entries' +
      (facetActive() ? ' (filtered)' : '') + ' (' + attn + ' attention in view)' +
      ' · digest ' + lastDigestLines + ' lines';
  }
  function bindFacets() {
    Array.prototype.forEach.call(
      document.querySelectorAll('#logs-reports .cf-chip'), function (b) {
        b.addEventListener('click', function () {
          var ev = b.getAttribute('data-fevent');
          facet.event = (facet.event === ev) ? '' : ev;
          applyFacets();
        });
      });
    var sel = $('logs-fjob');
    if (sel) sel.addEventListener('change', function () {
      facet.job = sel.value; applyFacets();
    });
    var txt = $('logs-ftext');
    if (txt) txt.addEventListener('input', function () {
      facet.text = txt.value; applyFacets(); // rows-only re-render: focus kept
    });
  }
  function applyFacets() {
    Array.prototype.forEach.call(
      document.querySelectorAll('#logs-reports .cf-chip'), function (b) {
        b.setAttribute('aria-pressed',
          String(b.getAttribute('data-fevent') === facet.event));
      });
    renderCrumbRows(); logsSum();
  }
  function setLogView(v) {
    var isDigest = v === 'digest';
    $('logs-reports').hidden = isDigest;
    $('logs-digest').hidden = !isDigest;
    $('lt-reports').classList.toggle('on', !isDigest);
    $('lt-digest').classList.toggle('on', isDigest);
    $('lt-reports').setAttribute('aria-selected', String(!isDigest));
    $('lt-digest').setAttribute('aria-selected', String(isDigest));
    try { sessionStorage.setItem('hngh-logs-view', isDigest ? 'digest' : 'reports'); } catch (e) { /* private mode */ }
  }
  function renderReports() {
    var body = $('logs-reports');
    if (!curCrumbs.length) { body.innerHTML = '<div class="ok-note">no reports</div>'; return; }
    var evCount = {}, jobCount = {};
    curCrumbs.forEach(function (c) {
      var ev = c.event || '(none)', jb = c.job || '(none)';
      evCount[ev] = (evCount[ev] || 0) + 1;
      jobCount[jb] = (jobCount[jb] || 0) + 1;
    });
    var chips = Object.keys(evCount).sort(function (a, b) {
      return evCount[b] - evCount[a];
    }).map(function (ev) {
      var on = facet.event === ev;
      return '<button type="button" class="cf-chip" data-fevent="' + esc(ev) + '"' +
        ' aria-pressed="' + on + '" title="filter reports by event">' +
        esc(ev) + ' ' + evCount[ev] + '</button>';
    }).join('');
    var jobs = Object.keys(jobCount).sort().map(function (jb) {
      return '<option value="' + esc(jb) + '"' + (facet.job === jb ? ' selected' : '') + '>' +
        esc(jb) + ' (' + jobCount[jb] + ')</option>';
    }).join('');
    body.innerHTML =
      '<div class="crumb-facets" role="group" aria-label="report filters">' +
      chips +
      '<select class="cf-input" id="logs-fjob" aria-label="filter by job">' +
      '<option value="">all jobs</option>' + jobs + '</select>' +
      '<input type="text" class="cf-input" id="logs-ftext" aria-label="filter detail text"' +
      ' placeholder="filter detail…" value="' + esc(facet.text) + '">' +
      '</div><div id="logs-rows"></div>';
    bindFacets();
    renderCrumbRows();
  }
  function renderDigest(d) {
    var body = $('logs-digest');
    var txt = '' + (d && d.digest ? d.digest : '');
    if (!txt) { body.innerHTML = '<div class="ok-note">no digest content</div>'; lastDigestLines = 0; return; }
    body.innerHTML = '<div class="digest md-body">' + miniMd(txt) + '</div>';
    lastDigestLines = txt.trim().split('\n').length;
  }
  function renderLogs(d, spine, res) {
    var opInfo = operatorItemsHtml();
    lastOpCount = opInfo.count;
    $('logs-ops').innerHTML =
      '<span class="ops-title">For the operator' + opInfo.counter + '</span>' + opInfo.html;
    curCrumbs = (d && d.breadcrumbs) || [];
    renderReports();
    renderDigest(d);
    logsSum();
    lastRender = { d: d, spine: spine, res: res };
    opRerenders.forEach(function (fn) { fn(); });
  }

  // ---------- mini markdown (escape-first; nothing else passes through) ----
  // Transforms ONLY: #/##/### headings, **bold**, - bullets, and
  // [text](url) links where the href is http(s):// or a bare <name>.md
  // (rewritten to the jailed /digest/ route). No raw html passthrough.
  function miniMd(txt) {
    var out = [], inUl = false;
    var inline = function (s) {
      s = s.replace(/\[([^\]]+)\]\(([^()\s]+)\)/g, function (_, t, u) {
        if (/^https?:\/\//i.test(u))
          return '<a href="' + u + '" target="_blank" rel="noopener">' + t + '</a>';
        if (/^[A-Za-z0-9._-]+\.md$/.test(u))
          return '<a href="/digest/' + u + '">' + t + '</a>';
        return t;
      });
      return s.replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>');
    };
    String(txt || '').split('\n').forEach(function (raw) {
      var l = esc(raw), m;
      if ((m = l.match(/^(#{1,3})\s+(.*)$/))) {
        if (inUl) { out.push('</ul>'); inUl = false; }
        out.push('<h' + (m[1].length + 3) + ' class="md-h">' + inline(m[2]) +
          '</h' + (m[1].length + 3) + '>');
      } else if ((m = l.match(/^\s*-\s+(.*)$/))) {
        if (!inUl) { out.push('<ul>'); inUl = true; }
        out.push('<li>' + inline(m[1]) + '</li>');
      } else {
        if (inUl) { out.push('</ul>'); inUl = false; }
        if (l.trim()) out.push('<p>' + inline(l) + '</p>');
      }
    });
    if (inUl) out.push('</ul>');
    return out.join('');
  }

  // ---------- global chrome ----------
  function setMeta(generated, source, noteHtml) {
    $('flow').innerHTML = 'source: <b>' + esc(source) + '</b> · generated ' + esc(ago(generated)) +
      (noteHtml ? ' · ' + noteHtml : '');
    $('last-refresh').textContent = 'refreshed ' + new Date().toLocaleTimeString();
  }
  function setBeacon(fresh) {
    var b = $('pulse');
    if (fresh === false) b.className = 'beacon warn';   // stale
    else if (fresh === null) b.className = 'beacon danger'; // unreachable
    else b.className = 'beacon ok';                     // fresh
  }

  function load() {
    fetchQueue(); // unread report rows: re-derived on every refresh + SSE change
    fetchOpState().then(function () {
      rerenderWithOpState();
    }).catch(function () {});
    return fetchJson('data.json').then(function (d) {
      // data.json is the primary source for digest/reports; try the spine too.
      return fetchJson('readout.json').then(function (sp) {
        return { d: d, spine: splatSpine(sp), source: 'data.json + readout.json', freshRes: true, generated: d.generated_at || sp.generated };
      }).catch(function () {
        return { d: d, spine: null, source: 'data.json (no spine)', freshRes: true, generated: d.generated_at };
      });
    }).catch(function () {
      // primary data.json missing/failed -> fallback: dashboard-readout --json via readout.json
      return fetchJson('readout.json').then(function (sp) {
        var spine = splatSpine(sp);
        var gen = spine.generated;
        var fresh = isFresh(gen);
        return { d: null, spine: spine, source: 'readout.json (data.json ' + (fresh ? 'stale' : 'missing/unreachable') + ')',
                 freshRes: fresh, generated: gen,
                 note: '<span class="stale-note">data.json unreachable — spine fallback</span>' };
      }).catch(function (e) {
        return { d: null, spine: null, source: 'none', freshRes: null, generated: null, error: e,
                 note: '<span class="missing-note">both data.json and readout.json unreachable</span>' };
      });
    }).then(function (res) {
      if (res.error) {
        var msg = 'Cannot reach data.json or readout.json (' + esc(res.error.message) + '). The dashboard is a pure reader; nothing is shown until a source is served.';
        $('logs-reports').innerHTML = '<div class="missing-note">' + msg + '</div>';
        $('logs-digest').innerHTML = '<div class="missing-note">' + msg + '</div>';
        headerNoSignal(msg);
        setMeta(null, 'none', res.note); setBeacon(null);
        return;
      }
      // staleness of the primary digest source
      var genD = res.generated && res.source.indexOf('data.json') === 0 ? res.generated : null;
      var fresh = genD ? isFresh(genD) : res.freshRes;
      var note = '';
      if (genD && !fresh) {
        note = '<span class="stale-note">data.json stale (&gt;5 min) — generated ' + esc(ago(genD)) + '</span>';
      }
      res.note = (res.note || '') + (note ? (res.note ? ' ' : '') + note : '');
      res.fresh = fresh;
      renderLogs(res.d, res.spine, res);
      renderHeader(res.d, res.spine, res);
    });
  }

  function splatSpine(sp) {
    // dashboard-readout --json yields {verdict, timeline, queue, etas, sessions, roster, generated}
    if (!sp || typeof sp !== 'object') return { verdict: null, timeline: [], queue: [], etas: {}, sessions: [], roster: [], generated: null };
    return {
      verdict: sp.verdict || null,
      timeline: Array.isArray(sp.timeline) ? sp.timeline.slice().reverse() : [],
      queue: Array.isArray(sp.queue) ? sp.queue : [],
      etas: sp.etas || {},
      sessions: Array.isArray(sp.sessions) ? sp.sessions : [],
      roster: Array.isArray(sp.roster) ? sp.roster : [],
      generated: sp.generated || null
    };
  }
  function isFresh(ts) {
    if (!ts) return false;
    var t = Date.parse(ts);
    if (isNaN(t)) return false;
    return (Date.now() - t) <= STALE_MS;
  }

  // ---------- SSE push (B6) ----------
  // /events streams a no-payload `change` per attention-feed mtime change
  // (operator-items / operator-dismissed / readout). While connected the
  // core 10s poll pauses (push replaces it); after two SSE failures we
  // fall back permanently to the P0 poll until reload. A hidden tab closes
  // the stream; becoming visible reopens it.
  var sse = null, sseFails = 0, sseSuppressed = false, corePoll = null;
  function sseStop(countFail) {
    if (!sse) return;
    var es = sse;
    sse = null;
    es.close();
    if (countFail) sseFails++;
  }
  function fallbackPoll() {
    if (!corePoll) corePoll = HnghPoll.start(load, { interval: REFRESH_MS });
  }
  function sseStart() {
    if (sse || !window.EventSource) { fallbackPoll(); return; }
    var es;
    try { es = new EventSource('/events'); } catch (e) {
      sseFails++;
      fallbackPoll();
      return;
    }
    sse = es;
    es.onopen = function () {
      sseFails = 0;
      if (corePoll) { corePoll.stop(); corePoll = null; } // push replaces the poll
    };
    es.addEventListener('change', function () {
      load();
      refreshCurrentView();
    });
    es.onerror = function () {
      if (sseSuppressed) return; // closed on purpose (hidden tab)
      sseStop(true);
      if (sseFails >= 2) { fallbackPoll(); return; } // P0 poll is the fallback path
      setTimeout(function () {
        if (!document.hidden) sseStart(); else fallbackPoll();
      }, Math.min(2000 * sseFails * sseFails, 60000));
    };
  }
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) {
      sseSuppressed = true;
      sseStop(false); // SSE closes while hidden (poll already pauses)
    } else {
      sseSuppressed = false;
      if (sseFails < 2) sseStart(); else fallbackPoll();
    }
  });

  // ---------- global bindings ----------
  function bindPanels() {
    $('refresh-btn').addEventListener('click', function () {
      load();
      refreshCurrentView();
    });
    $('lt-reports').addEventListener('click', function () { setLogView('reports'); });
    $('lt-digest').addEventListener('click', function () { setLogView('digest'); });
    var saved = null;
    try { saved = sessionStorage.getItem('hngh-logs-view'); } catch (e) { /* private mode */ }
    setLogView(saved === 'digest' ? 'digest' : 'reports');
    // hash deep link wins over the sessionStorage fallback: #tab-logs/digest
    var mh = location.hash.match(/^#tab-logs\/(digest|reports)/);
    if (mh) setLogView(mh[1]);
  }

  // ---------- theme (same key as gantt/sessions pages) ----------
  // winamp is the only theme: the classic skin IS the dashboard's look.
  (function () {
    var THEMES = ['winamp'];
    var t = null;
    try { t = localStorage.getItem('hngh-theme'); } catch (e) { /* private mode */ }
    if (THEMES.indexOf(t) < 0) t = 'winamp';
    document.documentElement.dataset.theme = t;
  }());

  // ---------- panel shade (classic roll-up: opt-in via data-shade) ----------
  // Big single-tab panels do NOT shade; a panel declares data-shade="1"
  // when roll-up genuinely helps (small, collapsible by nature).
  document.addEventListener('click', function (e) {
    if (e.target.closest('button, a, input, select, summary')) return;
    var head = e.target.closest('.panel-head');
    if (!head) return;
    var panel = head.closest('.panel');
    if (panel && panel.dataset.shade === '1') panel.classList.toggle('p-shade');
  });

  // ---------- formal tabs ----------
  // ONE state system: a tab activates by setting aria-selected on the tab and
  // both hidden + data-open on its panel.
  // Lazy-init: view modules (ScheduleView / SessionsView / SystemView /
  // ResearchView) init on FIRST activation and refresh() on later ones;
  // hidden panels have zero-size boxes, so modules only ever mount into a
  // just-un-hidden panel. The mount is name/root-paired: root↔tab↔global must
  // agree, or a cold-load retry mounts the WRONG module into a hidden panel
  // and marks the tab mounted (found by the schedule successor run).
  var MOUNTS = {
    'overview-root': ['overview', 'OverviewView'],
    'plans-root':    ['plans',    'PlansView'],
    'sched-root':   ['schedule', 'ScheduleView'],
    'sess-root':    ['sessions', 'SessionsView'],
    'system-root':  ['system',   'SystemView'],
    'research-root': ['research', 'ResearchView'],
    'kb-root':      ['kb',       'KBView'],
    'graph-root':   ['graph',    'GraphView'],
    'history-root': ['history',  'HistoryView'],
    'routes-root': ['routes',  'RoutesView']
  };
  var mounted = {};
  var currentTab = null;
  window.HnghTabs = {
    onActivate: function (fn) { /* kept for view hooks; currently unused */ }
  };
  // Camp (overview) and other views compose from what app.js already
  // fetched — no second fetch pipeline, no new endpoints.
  window.HnghOps = {
    data: function () { return lastRender; }, // {d, spine, res, ...} once loaded
    md: miniMd,
    html: operatorItemsHtml,
    verdict: verdictOf,
    post: postJson,
    token: hnghToken,
    expired: tokenExpiredChip,
    onOpChange: function (fn) { opRerenders.push(fn); }
  };
  // mini-markdown chrome shared by the Logs digest and Camp's excerpt
  (function () {
    var st = document.createElement('style');
    st.id = 'md-style';
    st.textContent = '.md-body{font-size:12.5px}' +
      '.md-body h4,.md-body h5,.md-body h6{margin:8px 0 2px;font-size:12.5px;' +
      'letter-spacing:.03em}.md-body ul{margin:2px 0 6px;padding-left:18px}' +
      '.md-body li{margin:2px 0}.md-body p{margin:4px 0}';
    document.head.appendChild(st);
  }());
  function mountAll(name) {
    Object.keys(MOUNTS).forEach(function (rootId) {
      var want = MOUNTS[rootId];
      if (want[0] !== name) return;
      var root = $(rootId);
      if (!root) return;
      var mod = window[want[1]];
      if (!mod || typeof mod.init !== 'function') {
        root.innerHTML = '<div class="missing-note">module loading — switch away and back once it lands</div>';
        return; // not marked mounted -> retried on next activation
      }
      if (!mounted[want[0]]) { mounted[want[0]] = true; mod.init(root); }
      else if (typeof mod.refresh === 'function') mod.refresh();
    });
  }
  // Refresh button refreshes the mounted view's own feed too, not just the
  // core header/logs feeds (the old button "lied" about the Sessions tab).
  function refreshCurrentView() {
    Object.keys(MOUNTS).forEach(function (rootId) {
      var want = MOUNTS[rootId];
      if (want[0] !== currentTab) return;
      var mod = window[want[1]];
      if (mod && typeof mod.refresh === 'function') mod.refresh();
    });
  }
  function initTabs() {
    var tabs = document.querySelectorAll('#tabs [role="tab"]');
    if (!tabs.length) return;
    // hash scheme: #tab-<name> selects a tab; #tab-logs/digest also sets the
    // Logs sub-view. Camp is reachable as #tab-overview.
    function hashTab() {
      var m = location.hash.match(/^#tab-([A-Za-z0-9_-]+)(?:\/([A-Za-z0-9_-]+))?/);
      return m ? { name: m[1], sub: m[2] || '' } : null;
    }
    function activate(name, push) {
      var known = false;
      tabs.forEach(function (t) { known = known || t.dataset.tab === name; });
      if (!known) name = tabs[0].dataset.tab; // stale/legacy hash -> first tab
      tabs.forEach(function (t) {
        var on = t.dataset.tab === name;
        t.setAttribute('aria-selected', String(on));
        t.classList.toggle('on', on);
      });
      currentTab = name;
      document.querySelectorAll('#grid .panel').forEach(function (p) {
        var want = p.id === 'p-' + name;
        p.hidden = !want;
        p.dataset.open = want ? '1' : '0';
      });
      mountAll(name);
      try { sessionStorage.setItem('hngh-tab', name); } catch (e) { /* private mode */ }
      if (push) history.replaceState(null, '', '#tab-' + name);
    }
    tabs.forEach(function (t) {
      t.addEventListener('click', function () { activate(t.dataset.tab, true); });
    });
    $('cnt-attention').addEventListener('click', function () { activate('overview', true); });
    window.addEventListener('hashchange', function () {
      var h = hashTab();
      var storedTab = null;
      try { storedTab = sessionStorage.getItem('hngh-tab'); } catch (e) { /* private mode */ }
      if (h && h.name === 'logs' && h.sub) setLogView(h.sub === 'digest' ? 'digest' : 'reports');
      if (h && h.name !== storedTab) activate(h.name, false);
    });
    var fromHash = hashTab();
    var stored = null;
    try { stored = sessionStorage.getItem('hngh-tab'); } catch (e) { /* private mode */ }
    activate(fromHash ? fromHash.name : (stored || 'overview'), false); // Camp (overview) is the default tab
    // Deferred view modules register after this (also-deferred) script runs,
    // so the initial activate() above found none of them. Re-run the mount
    // for the restored tab once every deferred script has executed.
    window.addEventListener('load', function () {
      if (!currentTab) return;
      mountAll(currentTab);
    });
  }

  // ---------- spin up ----------
  initTabs();
  bindPanels();
  load();
  corePoll = HnghPoll.start(load, { interval: REFRESH_MS });
  sseStart(); // connect push; onopen pauses the poll above
})();
