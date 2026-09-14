/* schedule-view — the Schedule tab's cascading view, mounted into
   index.html#p-schedule > #sched-root by app.js (window.ScheduleView =
   {init, refresh}; init on first tab activation, refresh() on later ones
   plus its own 60s poll). Renders the rotation queue from schedule.json
   (jobs/schedule-feed.py) through the shared cascading-gantt engine:

   · engine reuse: dashboard/gantt.js is loaded dynamically and driven via
     window.GanttEngine.mount(host, {embed:true}) — zoom (6h/24h/72h), drag
     pan, now-clamp, tooltips, honesty labels and deep links all belong to
     the engine; this module only classifies and feeds it.
   · classification (schedule.json): recurring entries render as lanes
     repeating on their cadence — occurrence bars are cadence projections
     anchored on the feed's last/next run, chips read
     '∷ recurring · every ~<interval> · ×N/24h'; one-off entries keep the
     engine's estimate bars + depends-on connectors, using the feed's own
     estimate_s / estimate_source / depends_on verbatim (never re-derived).
   · hngh vs system: the feed's hngh flag splits them. System lanes compact
     into one 'system backdrop' band (count on hover) unless the System
     filter is on, which places them on the timeline as real rows.
   · filters: All | Hngh | System | Recurring | One-off (this toolbar).
   · refresh() re-fetches schedule.json (+ small readout.json for the past
     timeline marks) and re-renders keyed: unchanged feed while hidden skips
     the render; any activation or feed change renders, so geometry is
     recomputed with real boxes once the tab is visible.
   sessions.json is fetched once at init (large) and only used by the
   engine for fuzzy bar→session deep links. All styles live in one owned
   <style> tag — style.css is not touched. Display layer only — never
   governance input. */
(function () {
  'use strict';

  var POLL_MS = 60000;

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fetchJson(url, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 8000);
    return fetch(url, { cache: 'no-store', signal: ctrl.signal })
      .then(function (r) { clearTimeout(t); if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
      .catch(function (e) { clearTimeout(t); throw e; });
  }
  function ago(ts) {
    var t = Date.parse(ts);
    if (isNaN(t)) return String(ts);
    var s = (Date.now() - t) / 1000;
    if (s < 90) return Math.round(s) + 's ago';
    if (s < 5400) return Math.round(s / 60) + 'm ago';
    if (s < 172800) return (Math.round(s / 3600 * 10) / 10) + 'h ago';
    return Math.round(s / 86400) + 'd ago';
  }
  function fmtDur(sec) {
    if (!(sec > 0)) return '?';
    if (sec < 90) return Math.round(sec) + 's';
    if (sec < 5400) return Math.round(sec / 60) + 'm';
    return (Math.round(sec / 3600 * 10) / 10) + 'h';
  }

  /* ---- owned styles (sch- prefix; engine classes come from style.css) ---- */
  var STYLE = [
    '.sch-line{color:var(--muted);font-size:11.5px;padding:2px 2px 6px;margin:0}',
    '.sch-bar{display:flex;gap:6px;align-items:center;flex-wrap:wrap;padding:0 2px 8px}',
    '.sch-fbtn{background:none;border:1px solid var(--line);border-radius:2px;',
    '  color:var(--muted);font-size:11px;padding:1px 9px;cursor:pointer;font:inherit}',
    '.sch-fbtn[aria-pressed="true"]{color:var(--accent);border-color:var(--accent)}',
    '.sch-jump{background:none;border:1px solid var(--line);border-radius:2px;',
    '  color:var(--ink);font-size:11px;padding:1px 9px;font:inherit;min-width:130px}',
    '.sch-jump:focus{outline:none;border-color:var(--accent)}',
    '.sch-status{color:var(--muted);font-size:11px;padding:6px 2px 0;',
    '  border-top:1px solid var(--line);margin-top:2px;font-variant-numeric:tabular-nums}',
    '.sch-sysband{border:1px dashed var(--line);border-radius:0;',
    '  background:repeating-linear-gradient(45deg,transparent,transparent 7px,',
    '  rgba(127,127,127,.05) 7px,rgba(127,127,127,.05) 8px);',
    '  padding:5px 10px;margin:0 2px 8px;color:var(--muted);font-size:11.5px;cursor:help}',
    '.sch-note{color:var(--danger);font-size:12px;padding:6px 2px}',
    '.sch-engine:empty::after{content:"engine loading…";color:var(--dim);font-size:12px}'
  ].join('\n');

  /* ---- state ---- */
  var root = null, host = null, api = null, ledgerData = null;
  var filter = 'all';
  var q = '';
  var sched = null, schedRaw = null, readout = null;
  var lastSig = null;

  var FILTERS = ['all', 'hngh', 'system', 'recurring', 'one-off'];

  /* ---- classification: schedule.json -> engine lane model ---- */
  function laneFromRecurring(r) {
    var est = r.p50_s != null ? { s: r.p50_s, src: 'ledger p50 (schedule feed)' }
      : r.last_wall_s != null ? { s: r.last_wall_s, src: 'last wall time (schedule feed)' }
      : null;
    return {
      id: r.name, kind: 'recurring', sys: r.hngh === false, src: r.source,
      est: est,
      rec: r.interval_s > 0 ? {
        everyS: r.interval_s, n: r.runs_24h, hint: r.interval_hint,
        tier: r.tier, lastEpoch: r.last_epoch, nextEpoch: r.next_epoch
      } : null
    };
  }
  function laneFromOneoff(o) {
    return {
      id: o.name, kind: 'oneoff', sys: false, src: null,
      est: o.estimate_s != null ? { s: o.estimate_s, src: o.estimate_source || 'feed estimate' } : null,
      deferred: o.placeholder === true || o.estimate_source === 'default 30m',
      dep: o.depends_on || null, rec: null
    };
  }
  // cascade order = row order: dependencies first (stable, cycle-safe)
  function topoOneoff(lanes) {
    var byId = {}, placed = {};
    lanes.forEach(function (l) { byId[l.id] = l; });
    function visit(l, stack) {
      if (placed[l.id]) return;
      if (stack[l.id]) { placed[l.id] = true; return; } // cycle: keep feed order
      stack[l.id] = true;
      if (l.dep && byId[l.dep]) visit(byId[l.dep], stack);
      placed[l.id] = true; out.push(l);
    }
    var out = [];
    lanes.forEach(function (l) { visit(l, {}); });
    return out;
  }
  function buildLanes() {
    var rec = (sched.recurring || []).map(laneFromRecurring);
    var one = topoOneoff((sched.oneoff || []).filter(function (o) { return o.status !== 'done'; })
      .map(laneFromOneoff));
    var hnghRec = rec.filter(function (l) { return !l.sys; });
    var sysRec = rec.filter(function (l) { return l.sys; });
    switch (filter) {
      case 'hngh': return hnghRec.concat(one);
      case 'system': return sysRec;
      case 'recurring': return rec;
      case 'one-off': return one;
      default: return hnghRec.concat(one); // 'all': system compacted to the backdrop band
    }
  }
  function systemLanes() {
    return (sched.recurring || []).map(laneFromRecurring)
      .filter(function (l) { return l.sys; });
  }

  function fmtCount(schedData) {
    var rec = schedData.recurring || [], one = schedData.oneoff || [];
    var nH = rec.filter(function (r) { return r.hngh !== false; }).length;
    var nS = rec.length - nH;
    var q = one.filter(function (o) { return o.status !== 'done'; });
    var nDef = q.filter(function (o) {
      return o.placeholder === true || o.estimate_source === 'default 30m';
    }).length;
    return nH + ' hngh recurring · ' + nS + ' system · ' +
      q.length + ' one-off queued (' + nDef + ' deferred, no estimate yet)';
  }

  function renderSysband() {
    var band = root.querySelector('.sch-sysband');
    if (!band) return;
    var sys = systemLanes();
    if (filter !== 'all' || !sys.length) { band.hidden = true; return; }
    var names = sys.map(function (l) {
      return esc(l.id) + ' — ' + esc(l.src || '?') +
        (l.rec ? ', every ~' + fmtDur(l.rec.everyS) : '') +
        (l.est ? ', last run EST ' + Math.round(l.est.s / 60) + 'm (' + esc(l.est.src) + ')' : '');
    }).join('<br>');
    band.innerHTML = '<span data-tip="<b>system backdrop</b> — ' + sys.length +
      ' non-hngh unit(s) ticking off-rotation:<br>' + names +
      '<br>compacted here; use the System filter to place them on the timeline">' +
      '▨ system backdrop · ' + sys.length +
      ' non-hngh unit' + (sys.length === 1 ? '' : 's') +
      ' tick off-rotation — hover for names · System filter places them on the timeline</span>';
    band.hidden = false;
  }

  function applyData(force) {
    if (!sched || !api) return;
    var raw = JSON.stringify(sched);
    var changed = raw !== lastSig;
    lastSig = raw;
    var lanes = buildLanes();
    if (q) lanes = lanes.filter(function (l) {
      return l.id.toLowerCase().indexOf(q) >= 0;
    });
    api.setLanes(lanes, sched.generated);
    api.setSpine(readout);
    api.note(null);
    renderSysband();
    var sum = document.getElementById('sched-sum');
    if (sum) sum.textContent = fmtCount(sched) + ' · feed @ ' + ago(sched.generated);
    var st = document.getElementById('sch-status');
    if (st) {
      var total = 0, nOne = 0;
      lanes.forEach(function (l) {
        if (l.est) total += l.est.s;
        if (l.kind === 'oneoff') nOne += 1;
      });
      st.textContent = lanes.length + ' lane' + (lanes.length === 1 ? '' : 's') +
        ' · ' + nOne + ' one-off · Σ wall/cycle ~' + fmtDur(total) +
        (q ? ' · filter "' + q + '"' : '');
    }
    // keyed re-render: skip when hidden and nothing moved; always render on
    // activation (refresh()) so boxes are recomputed against real geometry
    var visible = root && root.offsetParent !== null;
    if (force || changed || visible) api.render();
  }

  function fail(e) {
    if (api) api.note('schedule feed error: ' + e.message + ' — is hngh-dashboard.service up?');
    else if (host) host.innerHTML = '<div class="sch-note">schedule feed error: ' +
      esc(e.message) + ' — is hngh-dashboard.service up?</div>';
  }

  function refresh() {
    if (!root) {
      // app.js's mountModule is not name/rootId-paired: on the schedule tab it
      // can mount SessionsView (marking 'schedule' mounted) and then call
      // refresh() here without init() ever having run. Bootstrap ourselves.
      var r = document.getElementById('sched-root');
      if (r) { init(r); return; }
    }
    return Promise.all([
      fetchJson('schedule.json'),
      fetchJson('readout.json')
    ]).then(function (rs) {
      sched = rs[0]; readout = rs[1];
      applyData(true); // force: refresh() is also the tab-activation hook — recompute geometry
    }).catch(fail);
  }

  function init(el) {
    if (root && root.dataset.schedInit === '1') { refresh(); return; } // idempotent: app.js may init after self-mount
    root = el;
    root.dataset.schedInit = '1';
    var style = document.createElement('style');
    style.id = 'hngh-schedule-style';
    style.textContent = STYLE;
    document.head.appendChild(style);

    root.innerHTML =
      '<p class="sch-line">each row = one queued lane in the rotation queue &middot; ' +
      'bars are ESTIMATE projections, not schedule facts &middot; ' +
      'recurring lanes repeat on their cadence &middot; ' +
      'deferred lanes have no estimate candidate yet (chip, no bar)</p>' +
      '<div class="sch-bar">' +
      '<input class="sch-jump" id="sch-jump" type="text" placeholder="jump to lane ( / )"' +
      ' aria-label="filter lanes by name">' +
      FILTERS.map(function (f) {
        return '<button class="sch-fbtn" data-filter="' + f + '" aria-pressed="' +
          (f === filter) + '">' + f + '</button>';
      }).join('') +
      '</div>' +
      '<div class="sch-sysband" hidden></div>' +
      '<div class="sch-engine"></div>' +
      '<div class="sch-status" id="sch-status"></div>';

    root.querySelectorAll('.sch-fbtn').forEach(function (b) {
      b.addEventListener('click', function () {
        filter = b.dataset.filter;
        root.querySelectorAll('.sch-fbtn').forEach(function (x) {
          x.setAttribute('aria-pressed', String(x === b));
        });
        applyData(true);
      });
    });
    var jump = root.querySelector('.sch-jump');
    jump.addEventListener('input', function () {
      q = jump.value.trim().toLowerCase();
      applyData(true);
    });
    root.addEventListener('keydown', function (e) {
      if (e.key === '/' && document.activeElement !== jump) {
        e.preventDefault();
        jump.focus();
      } else if (e.key === 'Escape' && document.activeElement === jump) {
        jump.value = ''; q = ''; applyData(true);
      }
    });

    host = root.querySelector('.sch-engine');

    // engine load: gantt.js is not referenced by index.html — inject it here
    var s = document.createElement('script');
    s.src = 'gantt.js';
    s.onload = function () {
      if (!window.GanttEngine || typeof window.GanttEngine.mount !== 'function') {
        host.innerHTML = '<div class="sch-note">gantt engine loaded but exposed no mount point</div>';
        return;
      }
      api = window.GanttEngine.mount(host, { embed: true, onRefresh: refresh });
      if (ledgerData) api.setLedger(ledgerData); // fetch may beat script load
      if (sched) applyData(true); else refresh();
    };
    s.onerror = function () {
      host.innerHTML = '<div class="sch-note">gantt engine failed to load (dashboard/gantt.js)</div>';
    };
    document.head.appendChild(s);

    // sessions: fetched once (large); engine uses it only for bar→session deep links
    fetchJson('sessions.json').then(function (s2) {
      if (api) api.setSessions((s2 && s2.sessions) || []);
    }).catch(function () { /* deep links degrade silently — display only */ });

    // ledger: the engine's actual-bar source (drop-in / bridge walls)
    fetchJson('time-ledger.json').then(function (lg) {
      ledgerData = lg;
      if (api) api.setLedger(lg);
      if (sched) applyData(true);
    }).catch(function () { /* actual bars degrade to projections silently */ });

    refresh();
    window.HnghPoll.start(refresh, { interval: POLL_MS });
  }

  window.ScheduleView = { init: init, refresh: refresh };
})();