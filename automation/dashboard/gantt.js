/* hngh-automation · cascading gantt engine (gantt.html + Schedule tab)
   Pure reader. Every bar is an ESTIMATE with its source shown; projected
   starts are relative (now / depends-on satisfied) — no dates are invented.
   Display only: estimates and projections never feed governance.

   Two consumers:
   · gantt.html (standalone): skeleton already in DOM with the g* IDs —
     auto-mounts in legacy mode on load, fetches readout/ledger/sessions.
   · index.html Schedule tab: schedule-view.js loads this file, then calls
     window.GanttEngine.mount(host, {embed:true}) and feeds a unified lane
     model (setLanes/setSpine/setSessions) derived from schedule.json.       */
(function () {
  'use strict';

  var HOUR = 3600000;
  var WIN = 6 * HOUR;         // visible window (ms); zoom buttons set this
                              // 6h default: 30m estimate bars stay readable (8% of track)
  var PAST_FRAC = 1 / 3;      // fraction of the window showing actual past
  var PANOFF = 0;             // pan offset (ms)
  var ROW_H = 48, RULER_H = 28, MIN_BAR_PX = 6;
  var DEFAULT_EST_S = 30 * 60;
  var REFRESH_MS = 60000;
  var MAX_OCC = 48;           // per-lane occurrence cap; denser cadences -> one band

  var $ = function (id) { return document.getElementById(id); };
  var rzT, dragMovedFlag = false;   // pan-vs-click disambiguation + resize debounce
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

  /* ---------- theme (same key as sessions/index) ---------- */
  (function () {
    document.documentElement.dataset.theme = 'winamp';
  }());

  /* ---------- estimate chain (honesty law: source always named) ----------
     1. ledger p50 of the unit that historically ran this lane (token match)
     2. the lane's declared loadout time-limit fraction, from a session whose
        mission names the lane (TIME-LIMIT x 0.5)
     3. default 30m                                                        */
  function ledgerUnitFor(laneId, ledger, want) {
    if (!ledger || !Array.isArray(ledger.units)) return null;
    var toks = String(laneId).toLowerCase().split(/[^a-z0-9]+/)
      .filter(function (t) { return t.length >= 4; });
    var stop = ['hngh', 'automation', 'service', 'timer', 'path', 'shutdown', 'dashboard'];
    for (var i = 0; i < ledger.units.length; i++) {
      var u = ledger.units[i];
      var un = String(u.unit || '').toLowerCase();
      if (u.unit && (!want || want(un)) && toks.some(function (t) {
        return stop.indexOf(t) < 0 && un.indexOf(t) >= 0;
      })) return u;
    }
    return null;
  }
  /* measured wall for a lane from its drop-in / bridge ledger entries —
     the ACTUAL bar source (projected occurrences use the estimate chain) */
  function actualWallFor(laneId, ledger) {
    // exact identity first: this lane's own unit (or drop-in / bridge wall
    // entry) — a loose token match would dress one lane's wall as another's
    var id = String(laneId).toLowerCase();
    var u = null;
    if (ledger && Array.isArray(ledger.units)) {
      u = ledger.units.find(function (u) {
        var un = String(u.unit || '').toLowerCase();
        return un === id || un === id + '.service';
      });
    }
    if (!u) u = ledgerUnitFor(laneId, ledger, function (un) {
      return un.indexOf('dropin:') === 0 || un.indexOf('bridge:') === 0;
    });
    if (!u) return null;
    if (u.last_wall_s != null) return { s: u.last_wall_s, src: 'last wall' };
    if (u.p50_s != null) return { s: u.p50_s, src: 'ledger p50' };
    return null;
  }
  function ledgerEstimate(laneId, ledger) {
    var u = ledgerUnitFor(laneId, ledger);
    return (u && u.p50_s != null) ? { s: u.p50_s, src: 'ledger p50 ' + u.unit } : null;
  }
  /* recurring: the matched unit ran more than once in the last 24h;
     median interval between runs = 24h / runs_24h. Display only. */
  function recurringFor(laneId, ledger) {
    var u = ledgerUnitFor(laneId, ledger);
    if (!u || !(u.runs_24h > 1)) return null;
    return { n: u.runs_24h, everyS: 86400 / u.runs_24h };
  }
  function loadoutEstimate(laneId, sessions) {
    if (!Array.isArray(sessions)) return null;
    for (var i = 0; i < sessions.length; i++) {
      var s = sessions[i];
      if ((s.mission || '').toLowerCase().indexOf(String(laneId).toLowerCase()) < 0) continue;
      var tl = /:TIME-LIMIT (\d+)/.exec((s.detail && s.detail.tail) || '');
      if (tl) return { s: +tl[1] * 0.5, src: 'loadout time-limit ' + tl[1] + 's x0.5 (' + s.id + ')' };
    }
    return null;
  }
  function estimateFor(laneId, ledger, sessions) {
    return ledgerEstimate(laneId, ledger) ||
           loadoutEstimate(laneId, sessions) ||
           { s: DEFAULT_EST_S, src: 'default 30m' };
  }

  /* ---------- depends-on: parsed from etas text ("after <id>") ---------- */
  function depOf(laneId, etas, laneIds) {
    var m = /after\s+([a-z0-9._-]+)/i.exec((etas && etas[laneId]) || '');
    if (!m) return null;
    var dep = m[1].replace(/[.,;]$/, '');
    if (laneIds[dep]) return dep;
    if (dep.length < 4) return null; // "after a full session" -> token "a" is not a lane
    var hits = Object.keys(laneIds).filter(function (id) {
      return id.indexOf(dep) === 0;
    });
    return hits.length === 1 ? hits[0] : null; // "after node-lattice" -> node-lattice-admission
  }

  /* ---------- plan: cascading starts, all relative to "now" ---------- */
  function computePlan(lanes, est, depOfLane) {
    var start = {}, cycle = {}, laneIds = {};
    lanes.forEach(function (l) { laneIds[l.id] = true; });
    var dep = {};
    lanes.forEach(function (l) { dep[l.id] = depOfLane(l); });
    function place(id, visiting) {
      if (start[id] != null) return start[id];
      if (visiting[id]) { cycle[id] = true; return (start[id] = 0); } // fail-closed: pin to now
      var s = 0;
      if (dep[id]) {
        visiting[id] = true;
        s = place(dep[id], visiting) + ((est[dep[id]] && est[dep[id]].s) || 0) * 1000;
        delete visiting[id];
      }
      return (start[id] = s);
    }
    lanes.forEach(function (l) { place(l.id, {}); });
    return { start: start, cycle: cycle };
  }

  /* ---------- mounted view state ---------- */
  var view = null; // {root, embed, els:{sum,fresh,labels,tracks,err,tip}}
  var data = { spine: null, ledger: null, sessions: [], lanes: null };
  var tipEl = null;

  function el(k) {
    if (!view.embed) return $({ sum: 'gsum', fresh: 'fresh', labels: 'glabels',
      tracks: 'gtracks', err: 'gerr', tip: 'gtip' }[k]);
    return view.root.querySelector('.gt-' + k);
  }

  function buildSkeleton(root) {
    root.innerHTML =
      '<div class="gtoolbar">' +
        '<span class="gt-lab">window</span>' +
        [6, 24, 72].map(function (w) {
          return '<button class="ghost fbtn' + (w === 6 ? ' on' : '') +
            '" data-win="' + w + '">' + w + 'h</button>';
        }).join('') +
        '<span class="gcount gt-sum"></span>' +
        '<button class="ghost gt-refresh" title="refetch the schedule feed now">refresh now</button>' +
        '<span class="headline gt-fresh">awaiting feed&hellip;</span>' +
      '</div>' +
      '<div class="gt-err error" hidden></div>' +
      '<div class="gchart">' +
        '<div class="gcol-labels gt-labels"></div>' +
        '<div class="gcol-tracks gt-tracks"></div>' +
      '</div>' +
      '<div class="gtip gt-tip" hidden></div>';
  }

  function sessionFor(laneId) {
    for (var i = 0; i < data.sessions.length; i++) {
      if ((data.sessions[i].mission || '').toLowerCase().indexOf(String(laneId).toLowerCase()) >= 0)
        return data.sessions[i];
    }
    return null;
  }

  /* ---------- bars for one lane: cadence occurrences or a single estimate ---------- */
  function barsFor(l, plan, now, winStart, wpx, x) {
    var e = l.est;
    if (l.deferred) return { html: '', out: false }; // honesty: nothing estimated -> no solid bar
    var tipHead = '<b>' + esc(l.id) + '</b><br>kind: ' +
      (l.rec ? 'recurring' + (l.src ? ' (source: ' + esc(l.src) + ')' : '') : 'one-off') +
      '<br>duration: ' + (e ? 'ESTIMATE from ' + esc(e.src) + ' (' + esc(fmtDur(e.s)) + ')'
                           : 'unknown — feed has no p50 / wall time');

    function bar(left, w, tip, extraCls, lab) {
      var ses = sessionFor(l.id);
      return '<div class="gbar ' + (extraCls || '') +
        '" data-tip="' + esc(tip) + '"' +
        (ses ? ' data-goto="run-' + esc(ses.id) + '" title="open session ' + esc(ses.id) + '"' : '') +
        ' style="left:' + left + '%;width:' + w + '%">' +
        '<span class="gbar-lab">' + (lab || '') + '</span></div>';
    }

    if (l.rec && l.rec.everyS > 0 && (l.rec.nextEpoch != null || l.rec.lastEpoch != null)) {
      var iv = l.rec.everyS * 1000;
      var anchor = l.rec.nextEpoch != null ? l.rec.nextEpoch * 1000
                 : l.rec.lastEpoch * 1000;
      var nWin = Math.ceil(WIN / iv);
      var recTip = tipHead +
        '<br>cadence: every ~' + esc(fmtDur(l.rec.everyS)) +
        (l.rec.hint ? ' (' + esc(l.rec.hint) + ')' : '') +
        (l.rec.n != null ? ' · ×' + l.rec.n + ' runs/24h' : '') +
        '<br>placement: cadence projection anchored on the feed\'s last/next run — a projection, not a scheduled fact';
      // the one ACTUAL: the last real run's measured wall at its feed
      // anchor, solid — distinct from dashed projections. Drawn first: the
      // dense-band shortcut below must not swallow it (one actual bar is
      // immune to the thousands-of-occurrences problem)
      var act = l.rec.lastEpoch != null ? actualWallFor(l.id, data.ledger) : null;
      var actHtml = '';
      if (act) {
        var tAct = l.rec.lastEpoch * 1000;
        var aLeft = x(tAct);
        var aRight = Math.min(100, x(tAct + act.s * 1000));
        var aW = Math.max(MIN_BAR_PX / wpx * 100, aRight - aLeft);
        actHtml = bar(aLeft, aW,
          tipHead + '<br><b>actual ' + esc(fmtDur(act.s)) + ' (' + esc(act.src) + ')</b>' +
          '<br>measured wall of the last real run at its feed anchor; dashed bars are projections',
          'gbar-actual');
      }
      if (nWin > MAX_OCC) {
        // ponytail: dense cadence (e.g. 1m ticks) renders as one band, not thousands of bars
        return { html: actHtml + bar(0, 100, recTip + '<br>too dense to place individually: ×' +
          nWin + ' runs inside this window — shown as one band', 'gbar-recur'), out: false };
      }
      var phase = ((anchor - winStart) % iv + iv) % iv;
      var out = '';
      for (var t = winStart + phase; t <= winStart + WIN; t += iv) {
        var left = x(t);
        var right = Math.min(100, x(t + (e ? e.s * 1000 : 0)));
        var w = Math.max(MIN_BAR_PX / wpx * 100, right - left);
        var when = t <= now ? 'last/projected occurrence' : 'next projected occurrence';
        out += bar(left, w, recTip + '<br>' + when + ': now' +
          (t - now >= 0 ? ' + ' + esc(fmtDur((t - now) / 1000)) : ' − ' + esc(fmtDur((now - t) / 1000))),
          'gbar-recur');
      }
      if (out === '') {
        // no occurrence lands inside the window (cadence longer than the
        // window): pin one honest marker at the right edge for the next one
        var tNext = winStart + phase;
        out = bar(Math.min(96, x(tNext)), Math.max(1.2, MIN_BAR_PX / wpx * 100),
          recTip + '<br>next projected occurrence: now + ' +
          esc(fmtDur((tNext - now) / 1000)) +
          ' — outside this window; pinned at the edge', 'gbar-recur');
      }
      out += actHtml;
      return { html: out, out: false };
    }

    // single estimate bar (one-off cascade, or recurring without an anchor)
    if (!e) return { html: '', out: false };
    var sMs = now + plan.start[l.id]; // place() already returns ms
    var left = x(sMs), right = Math.min(100, x(sMs + e.s * 1000));
    var w = Math.max(MIN_BAR_PX / wpx * 100, right - left);
    var pxw = w * wpx / 100;          // rendered pixel width (>= MIN_BAR_PX)
    var o = pxw < 56, outL = o && left > 80;
    var ses = sessionFor(l.id);
    var depTxt = l.dep
      ? 'depends on: ' + esc(l.dep) + (plan.cycle[l.id] ? ' (cycle detected — start pinned to now)' : '')
      : (l.rec ? '' : 'no depends-on — eligible now');
    var tip = tipHead +
      (depTxt ? '<br>' + depTxt : '') +
      (l.rec ? '<br>recurring: every ~' + esc(fmtDur(l.rec.everyS)) +
        (l.rec.n != null ? ' · ×' + l.rec.n + ' runs/24h' : '') : '') +
      '<br>start: projected at ' + (plan.start[l.id] > 0 ? 'now + ' + esc(fmtDur(plan.start[l.id] / 1000)) : 'now') +
      (ses ? '<br>session: ' + esc(ses.id || ses.store) : '');
    return {
      html: bar(left, w, tip, (l.rec ? 'gbar-recur ' : '') +
        (o ? 'gbar-out' + (outL ? ' gbar-out-l' : '') : ''),
        o ? esc(fmtDur(e.s)) + ' EST' : 'EST ' + esc(fmtDur(e.s))),
      out: o
    };
  }
  /* ---------- work-graph plan block (step 2) ----------
     Fact rows, not projections: filled cell = done step, pulsing = next
     unchecked step, hollow = later steps. Blocked-by markers come ONLY
     from the feed's edges list (intra-plan step deps); park-cause chips
     come from the cause field. Nothing time-anchored is invented here —
     these rows sit below the schedule grid and ignore the time axis. */
  var PL_ROW_H = 24;

  function planStepTip(p, s) {
    return '<b>' + esc(p.slug) + ' · step ' + s.n + '</b><br>' +
      esc(s.title || '') +
      '<br>fact: ' + (s.done ? 'done (plan checkbox)' : 'not completed yet') +
      (s.verification
        ? '<br>verification: ' + esc(String(s.verification).slice(0, 160))
        : '');
  }

  function planLane(p, edgesByTo) {
    var steps = Array.isArray(p.steps) ? p.steps : [];
    var n = Math.max(1, steps.length || p.steps_total || 1);
    var next = null; // first unchecked step in plan order
    var k;
    for (k = 0; k < steps.length; k++) {
      if (!steps[k].done) { next = steps[k]; break; }
    }
    var w = 'calc(' + (100 / n) + '% - 2px)';
    var out = '<div class="psteps">';
    for (k = 0; k < steps.length; k++) {
      var s = steps[k];
      var cls = s.done ? 'pstep-done' : (next && s.n === next.n ? 'pstep-next' : 'pstep-todo');
      var unlocked = ((edgesByTo[p.slug] || {})[s.n]);
      var edgeTip = unlocked && unlocked.length
        ? '<br>unlocks work-graph step' + (unlocked.length > 1 ? 's' : '') +
          ' ' + esc(unlocked.join(', ')) + ' (feed edges list)'
        : '';
      out += '<div class="pstep ' + cls + '" data-tip="' +
        esc(planStepTip(p, s) + edgeTip) + '" style="width:' + w + '">' +
        (unlocked && unlocked.length ? '<span class="pstep-edge">→</span>' : '') +
        '</div>';
    }
    return out + '</div>';
  }

  function planRows() {
    var f = data.plansFeed;
    if (!f || !Array.isArray(f.plans) || !f.plans.length) return null;
    var active = f.plans.filter(function (p) {
      return p.status === 'accepted' || p.status === 'executing';
    });
    active.sort(function (a, b) {
      return (Date.parse(b.accepted) || 0) - (Date.parse(a.accepted) || 0);
    });
    // intra-plan edges: step m unlocks step n -> key by (slug, to)
    var edgesByTo = {};
    active.forEach(function (p) {
      (p.edges || []).forEach(function (e) {
        if (e.type !== 'unlocks' && e.type !== 'feeds') return;
        if (!edgesByTo[p.slug]) edgesByTo[p.slug] = {};
        if (!edgesByTo[p.slug][e.to]) edgesByTo[p.slug][e.to] = [];
        edgesByTo[p.slug][e.to].push(e.from);
      });
    });
    var head = 'work graph — plans';
    if (!active.length) {
      return { labels: '<div class="glabel-row phead" style="height:' + PL_ROW_H +
        'px"><span class="gname">' + esc(head) +
        '</span><span class="gest">no accepted or executing plans right now</span></div>',
        tracks: '<div class="gtrack-row" style="height:' + PL_ROW_H + 'px"></div>' };
    }
    var labels = '<div class="glabel-row phead" style="height:' + PL_ROW_H + 'px">' +
      '<span class="gname">' + esc(head) + '</span><span class="gest">fact rows: each cell is one step — ' +
      esc('filled = done, pulse = next unchecked (plan checkboxes, not estimates)') + '</span></div>';
    var tracks = '<div class="gtrack-row" style="height:' + PL_ROW_H + 'px"></div>';
    // one parked sample per cause family; cause chip straight from the cause field
    var parkedSeen = {};
    var parked = f.plans.filter(function (p) {
      if (p.status !== 'parked' || !p.cause || parkedSeen[p.cause]) return false;
      parkedSeen[p.cause] = true;
      return true;
    }).sort(function (a, b) {
      return (Date.parse(b.accepted) || 0) - (Date.parse(a.accepted) || 0);
    }).slice(0, 3);
    var rows = active.concat([null]).concat(parked); // spacer row then parked samples
    rows.forEach(function (p) {
      if (!p) {
        labels += '<div class="glabel-row" style="height:10px"></div>';
        tracks += '<div class="gtrack-row" style="height:10px"></div>';
        return;
      }
      if (p.status === 'parked') {
        labels += '<div class="glabel-row pgeneral" style="height:' + PL_ROW_H + 'px">' +
          '<span class="gname">' + esc(p.slug) + '</span>' +
          '<span class="gest">parked — cause (feed)</span>' +
          '<span class="pchip-cause" data-tip="' + esc(p.cause) + '">' + esc(p.cause) + '</span></div>';
        tracks += '<div class="gtrack-row" style="height:' + PL_ROW_H + 'px"></div>';
        return;
      }
      labels += '<div class="glabel-row" style="height:' + PL_ROW_H + 'px" title="' +
        esc(p.slug + ' — ' + p.status + ' · ' + p.steps_done + '/' + p.steps_total + ' steps done') + '">' +
        '<span class="gname">' + esc(p.slug) + '</span>' +
        '<span class="gest">' + esc(p.status) + ' · ' + p.steps_done + '/' + p.steps_total + ' steps</span>' +
        '</div>';
      tracks += '<div class="gtrack-row" style="height:' + PL_ROW_H + 'px">' +
        planLane(p, edgesByTo) + '</div>';
    });
    return { labels: labels, tracks: tracks };
  }


  /* ---------- render ---------- */
  function render() {
    var lanes = data.lanes;
    var sp = data.spine;
    if (!lanes && !sp) return;
    if (!lanes) {
      // legacy standalone: derive the lane model from the readout spine
      var etas = sp.etas || {}, laneIds = {};
      (sp.queue || []).forEach(function (q) { laneIds[q.id] = true; });
      lanes = (sp.queue || []).filter(function (q) { return q.status !== 'done'; })
        .map(function (q) {
          var rec = recurringFor(q.id, data.ledger);
          var est = estimateFor(q.id, data.ledger, data.sessions);
          return {
            id: q.id, status: q.status,
            kind: 'oneoff', est: est,
            deferred: est.src === 'default 30m',
            dep: depOf(q.id, etas, laneIds),
            rec: rec ? { everyS: rec.everyS, n: rec.n } : null
          };
        });
      data.lanes = lanes;
    }

    var tracksEl = el('tracks'), sumEl = el('sum'), labelsEl = el('labels'), freshEl = el('fresh');
    if (!tracksEl) return;
    sumEl.textContent = lanes.length + ' lanes · showing ' +
      Math.round(WIN * PAST_FRAC / HOUR) + 'h back / ' + Math.round(WIN * (1 - PAST_FRAC) / HOUR) + 'h ahead';

    // dependency cascade: one-off lanes chain, recurring lanes anchor on their own cadence
    var est = {};
    lanes.forEach(function (l) { est[l.id] = l.est; });
    var plan = computePlan(lanes, est, function (l) { return l.dep || null; });

    var now = Date.now();
    var winStart = now - WIN * PAST_FRAC + PANOFF;
    var wpx = tracksEl.clientWidth || 600;
    var x = function (ms) { return Math.max(-5, (ms - winStart) / WIN * 100); }; // percent
    var nowPct = Math.max(0, Math.min(100, (now - winStart) / WIN * 100));

    // ruler ticks: first ladder step giving >= ~84px per tick
    var LADDER = [5, 10, 15, 30, 60, 120, 180, 360, 720, 1440]; // minutes
    var stepMin = LADDER[LADDER.length - 1];
    for (var i = 0; i < LADDER.length; i++) {
      if (wpx / (WIN / 60000 / LADDER[i]) >= 84) { stepMin = LADDER[i]; break; }
    }
    var stepMs = stepMin * 60000, ticks = '';
    for (var t = Math.ceil(winStart / stepMs) * stepMs; t <= winStart + WIN; t += stepMs) {
      var d = new Date(t);
      var lab = d.getHours() === 0 && d.getMinutes() === 0
        ? d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
        : ('0' + d.getHours()).slice(-2) + ':' + ('0' + d.getMinutes()).slice(-2);
      ticks += '<span class="gtick" style="left:' + x(t) + '%">' + esc(lab) + '</span>';
    }

    // actual past events (day precision from the readout timeline)
    var marks = (sp && sp.timeline || []).map(function (r) {
      return { t: Date.parse(r[0]), kind: r[1], name: r[2] };
    }).filter(function (e) {
      return !isNaN(e.t) && e.t >= winStart && e.t <= now;
    }).map(function (e) {
      return '<div class="gmark" data-tip="actual: ' + esc(e.kind) + ' ' + esc(e.name) +
        ' on ' + esc(new Date(e.t).toISOString().slice(0, 10)) + ' (day precision, readout timeline)" style="left:' + x(e.t) + '%"></div>';
    }).join('');

    var labels = '<div class="glabel-row glabel-head" style="height:' + RULER_H + 'px">lane</div>';
    var tracks = '';
    var idx = {}, lines = [];
    lanes.forEach(function (l, i) { idx[l.id] = i; });

    lanes.forEach(function (l, i) {
      var e = l.est;
      var rec = l.rec;
      // classification chip — every lane answers "recurring on what schedule" or is one-off
      var chip = '';
      if (rec && rec.everyS > 0) {
        chip = '<span class="gchip-recur">∷ every ~' + esc(fmtDur(rec.everyS)) +
          (rec.n != null ? ' · ' + rec.n + ' runs/24h' : '') +
          (rec.tier ? ' · ' + esc(rec.tier) + ' tier' : '') + '</span>';
      } else if (l.kind === 'recurring') {
        chip = '<span class="gchip-recur">∷ recurring · ' +
          (l.src === 'gbd-lane' ? 'operator-run, no fixed cadence' : 'cadence unspecified') + '</span>';
      } else if (l.kind === 'oneoff') {
        chip = '<span class="gchip-oneoff">one-off</span>';
      }
      if (l.deferred) chip += '<span class="gchip-deferred">deferred — candidates pending</span>';
      // last-run honesty: the feed's own anchor (schedule.json last_epoch)
      if (l.rec) {
        chip += l.rec.lastEpoch != null
          ? '<span class="gchip-recur">last run ' + esc(fmtDur(Math.max(0, now / 1000 - l.rec.lastEpoch))) + ' ago</span>'
          : '<span class="gchip-recur">no run anchor yet</span>';
      }
      labels += '<div class="glabel-row' + (l.deferred ? ' glabel-deferred' : '') +
        '" title="' + esc(l.id) + (e ? ' — ESTIMATE from ' + esc(e.src) : ' — no estimate available (feed)') +
        '" style="height:' + ROW_H + 'px">' +
        '<span class="gname">' + esc(l.id) + '</span>' +
        '<span class="gest">' + (e ? 'ESTIMATE from ' + esc(e.src) : 'no estimate available (feed)') + '</span>' +
        chip +
        '</div>';
      var b = barsFor(l, plan, now, winStart, wpx, x);
      var rowTip = l.deferred
        ? ' data-tip="<b>' + esc(l.id) + '</b><br>deferred — no ledger p50 or loadout time-limit ' +
          'candidate matched this lane, so nothing is estimated yet (the 30m default only ' +
          'drives relative cascade order, no bar is drawn)"'
        : (l.rec && !b.html)
        ? ' data-tip="<b>' + esc(l.id) + '</b><br>recurring lane with no run anchor in the feed ' +
          '(last/next run unknown) and no duration estimate — no bars placed rather than invented' +
          (l.rec.everyS ? '; cadence: every ~' + esc(fmtDur(l.rec.everyS)) : '') + '"'
        : '';
      tracks += '<div class="gtrack-row"' + rowTip + ' style="height:' + ROW_H + 'px">' + b.html + '</div>';
      if (l.dep && idx[l.dep] != null && !plan.cycle[l.id]) {
        var dl = lanes[idx[l.dep]], de = dl && dl.est;
        if (de) {
          var dx = x(now + plan.start[l.dep] + de.s * 1000);
          var y1 = RULER_H + idx[l.dep] * ROW_H + ROW_H / 2, y2 = RULER_H + i * ROW_H + ROW_H / 2;
          var left = Math.max(0, x(now + plan.start[l.id]));
          var midx = (dx + left) / 2;
          lines.push('<polyline class="gline" points="' + dx + ',' + y1 + ' ' + midx + ',' + y1 +
            ' ' + midx + ',' + y2 + ' ' + left + ',' + y2 + '"/>');
          lines.push('<circle class="gline-dot" cx="' + dx + '" cy="' + y1 + '" r="2.5"/>');
        }
      }
    });

    var plansBlock = planRows(); // work-graph plan lanes below the schedule grid
    if (plansBlock) {
      labels += plansBlock.labels;
      tracks += plansBlock.tracks;
    }

    labelsEl.innerHTML = labels;
    tracksEl.innerHTML =
      '<div class="gruler" style="height:' + RULER_H + 'px">' + ticks + '</div>' +
      '<div class="gpast" style="left:0;width:' + nowPct + '%"></div>' +
      '<div class="gproj" style="left:' + nowPct + '%;right:0"><span>projected &mdash; relative starts, no scheduled dates</span></div>' +
      '<div class="gnow" style="left:' + nowPct + '%"><span>now</span></div>' +
      '<svg class="glines" width="100%" height="100%">' + lines.join('') + '</svg>' +
      marks + tracks;

    if (freshEl) {
      freshEl.textContent = data.lanesSource
        ? 'schedule @ ' + ago(data.lanesSource) + ' · readout @ ' + ago(sp && sp.generated)
        : 'readout @ ' + ago(sp && sp.generated) +
          ' · ledger @ ' + ago(data.ledger && data.ledger.generated_at);
    }
  }

  /* ---------- tooltip ---------- */
  function bindDoc() {
    document.addEventListener('mouseover', function (e) {
      var t = e.target.closest('[data-tip]');
      if (!t || !tipEl) { if (tipEl) tipEl.hidden = true; return; }
      tipEl.innerHTML = t.getAttribute('data-tip');
      tipEl.hidden = false;
    });
    document.addEventListener('mousemove', function (e) {
      if (!tipEl || tipEl.hidden) return;
      tipEl.style.left = Math.min(e.clientX + 12, window.innerWidth - tipEl.offsetWidth - 8) + 'px';
      tipEl.style.top = Math.min(e.clientY + 12, window.innerHeight - tipEl.offsetHeight - 8) + 'px';
    });
    document.addEventListener('mouseout', function (e) {
      if (!tipEl || tipEl.hidden) return;
      if (!e.relatedTarget || !e.relatedTarget.closest || !e.relatedTarget.closest('[data-tip]')) tipEl.hidden = true;
    });

    /* ---------- click through to sessions ---------- */
    document.addEventListener('click', function (e) {
      if (dragMovedFlag) return;
      var b = e.target.closest('[data-goto]');
      if (!b) return;
      if (view.embed) {
        // embedded: the session observatory lives on the sessions tab
        try { sessionStorage.setItem('hngh-tab', 'sessions'); } catch (err) { /* private mode */ }
        location.hash = 'tab-sessions';
      } else {
        location.href = 'sessions.html#' + b.getAttribute('data-goto');
      }
    });
  }

  /* ---------- mount ---------- */
  function mount(root, opts) {
    opts = opts || {};
    var embed = !!opts.embed;
    view = { root: root, embed: embed };
    // engine-owned chip/muted styles (style.css is shared; these stay additive)
    if (!document.getElementById('gantt-engine-style')) {
      var st = document.createElement('style');
      st.id = 'gantt-engine-style';
      st.textContent =
        '.gchip-oneoff{color:var(--dim);font-size:10px;border:1px solid var(--line);' +
        'border-radius:0;padding:0 6px;white-space:nowrap}' +
        '.gchip-deferred{color:var(--muted);font-size:10px;font-style:italic;' +
        'border:1px dashed var(--line);border-radius:0;padding:0 6px;white-space:nowrap}' +
        '.gbar-actual{background:rgba(102,187,106,.35);border:1px solid #66bb6a;z-index:3}' +
        '.glabel-deferred{opacity:.72}' +
        '.glabel-deferred .gest{color:var(--muted);font-style:italic}' +
        /* work-graph plan block (step 2) — fact cells and cause chips */
        '.phead{border-top:1px solid var(--line);margin-top:8px}' +
        '.phead .gname{color:var(--muted);text-transform:uppercase;font-size:10px;letter-spacing:.06em}' +
        '.phead-track{height:' + PL_ROW_H + 'px}' +
        '.psteps{display:flex;gap:2px;width:100%;align-items:stretch}' +
        '.pstep{position:relative;height:100%;min-width:4px;background:transparent;' +
        'border:1px solid var(--line)}' +
        '.pstep-done{background:rgba(102,187,106,.45);border-color:#66bb6a}' +
        '.pstep-todo{opacity:.55}' +
        '.pstep-next{border-color:var(--accent);animation:gpulse 1.6s ease-in-out infinite}' +
        '.pstep-edge{position:absolute;inset:auto 0 auto auto;font-size:9px;color:var(--accent);line-height:1}' +
        '.pchip-cause{color:var(--muted);font-size:10px;border:1px dashed var(--line);' +
        'border-radius:0;padding:0 6px;white-space:nowrap}' +
        '@keyframes gpulse{0%,100%{background:transparent}50%{background:rgba(47,129,247,.25)}}'
      document.head.appendChild(st);
    }
    if (embed) buildSkeleton(root);
    // legacy standalone: the gantt.html skeleton (g* IDs) is already in the DOM
    tipEl = el('tip');
    bindDoc();

    // zoom
    root.querySelectorAll('.fbtn[data-win]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        root.querySelectorAll('.fbtn[data-win]').forEach(function (b) { b.classList.remove('on'); });
        btn.classList.add('on');
        WIN = (+btn.getAttribute('data-win')) * HOUR;
        PANOFF = 0;
        render();
      });
    });

    // drag pan
    (function () {
      var t = el('tracks'), downX = null;
      t.addEventListener('pointerdown', function (e) {
        downX = e.clientX;
        try { t.setPointerCapture(e.pointerId); } catch (err) { /* already released */ }
      });
      t.addEventListener('pointermove', function (e) {
        if (downX == null) return;
        var dx = e.clientX - downX;
        if (Math.abs(dx) < 4) return;
        dragMovedFlag = true;
        downX = e.clientX;
        PANOFF -= dx / (t.clientWidth || 600) * WIN;
        PANOFF = Math.max(-2 * WIN / 3, Math.min(WIN / 3, PANOFF)); // keep "now" in view
        render();
      });
      ['pointerup', 'pointercancel'].forEach(function (ev) {
        t.addEventListener(ev, function () {
          downX = null;
          if (dragMovedFlag) setTimeout(function () { dragMovedFlag = false; }, 0);
        });
      });
      window.addEventListener('resize', function () {
        clearTimeout(rzT); rzT = setTimeout(render, 200);
      });
    })();

    var api = {
      render: render,
      setLanes: function (lanes, generated) { data.lanes = lanes; data.lanesSource = generated; },
      setLedger: function (ledger) { data.ledger = ledger; },
      setSpine: function (sp) { data.spine = sp; },
      setSessions: function (list) { data.sessions = list || []; },
      note: function (msg) {
        var g = el('err');
        if (!g) return;
        if (msg) { g.textContent = msg; g.hidden = false; } else { g.hidden = true; }
      },
    };

    if (embed) {
      var rb = root.querySelector('.gt-refresh');
      if (rb && typeof opts.onRefresh === 'function') rb.addEventListener('click', opts.onRefresh);
      return api;
    }

    /* ---------- legacy standalone loop (gantt.html) ---------- */
    function refresh() {
      return Promise.all([
        fetchJson('readout.json'),
        fetchJson('time-ledger.json'),
        fetchJson('sessions.json'),
        fetchJson('plans.json').catch(function () { return null; }) // fail-closed: schedule still renders
      ]).then(function (rs) {
        data.spine = rs[0];
        data.ledger = rs[1];
        data.sessions = (rs[2] && rs[2].sessions) || [];
        data.plansFeed = rs[3];
        data.lanes = null; // re-derive from the spine
        api.note(null);
        render();
      }).catch(function (e) {
        api.note('feed error: ' + e.message + ' — is hngh-dashboard.service up?');
      });
    }
    var refreshBtn = $('refresh-btn');
    if (refreshBtn) refreshBtn.addEventListener('click', refresh);
    refresh();
    setInterval(refresh, REFRESH_MS);
    api.refresh = refresh;
    return api;
  }

  /* standalone page: mount immediately into the existing skeleton */
  if ($('gtracks')) mount(document.body);
  else window.GanttEngine = { mount: mount };
})();