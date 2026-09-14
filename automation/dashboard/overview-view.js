/* overview-view — the Camp tab (canonical term: overview; see
   docs/design/display-register-spec.md — Camp is the display alias, the
   canonical term is never renamed). Mounted into index.html#p-overview >
   #overview-root by app.js (window.OverviewView = {init, refresh}; init on
   first tab activation, refresh() on later ones).

   Camp is the landing view. It composes ONLY the JSONs app.js already
   fetched (data.json, readout.json, operator-items.json via window.HnghOps)
   — no fetch pipeline of its own, no new endpoints:

   · verdict pill + its reasons as VISIBLE text lines (the header strip kept
     them hover-only);
   · open operator items with the shared arm/confirm dismiss flow
     (HnghOps.html / POST /operator-item/dismiss); handled items collapsed
     in a <details>;
   · the five most recent attention crumbs;
   · today's dispatch excerpt — the first ~30 digest lines through the
     shared mini-markdown renderer, plus a "full dispatch" link to the
     jailed GET /digest/<today>.md route;
   · a small deep-links row (Logs, Research).

   Re-renders skip when nothing visible changed, so the 10s poll never
   collapses an operator-open <details>. Display layer only — never
   governance input. */
(function () {
  'use strict';

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  /* ---- owned styles (ov- prefix) ---- */
  var STYLE = [
    '.ov{max-width:1320px}',
    '.ov-block{margin:0 0 10px}',
    '.ov-verdict{margin:0 0 6px}',
    '.ov-reasons{color:var(--muted);font-size:12.5px;margin:0 0 4px;padding-left:2px}',
    '.ov-reasons div{margin:2px 0}',
    '.ov-reasons div::before{content:"· ";color:var(--accent)}',
    '.ov details{margin:4px 0}',
    '.ov summary{cursor:pointer;color:var(--muted);font-size:12px;list-style:none}',
    '.ov summary::before{content:"+ ";color:var(--accent)}',
    '.ov details[open] summary::before{content:"− "}',
    '.ov-links a{color:var(--accent);font-size:12px;margin-right:14px}',
    '.ov-note{color:var(--muted);font-size:12px}'
  ].join('\n') +
    // B7 view half: the spend stat reads /telemetry.json (server feed);
    // the sparkline is a bare inline SVG polyline, no deps.
    '.ov-tele-val{font-size:13px;color:var(--ink)}' +
    '.ov-spark{display:block;margin-top:4px}';

  var root = null, lastHtml = null;

  function verdictBlock(d, spine) {
    var v = window.HnghOps.verdict(d, spine);
    var reasons = (v.reasons || []).slice();
    var ops = window.HnghOps.html(null);
    if (ops.open > 0)
      reasons.push(ops.open + ' open operator item' + (ops.open === 1 ? '' : 's'));
    var lines = reasons.length
      ? '<div class="ov-reasons">' + reasons.map(function (r) {
          return '<div>' + esc(r) + '</div>';
        }).join('') + '</div>'
      : '<div class="ov-note">no reasons recorded — the verdict stands on the digest text alone</div>';
    return '<div class="ov-block ov-verdict">' +
      '<span class="strip-verdict ' + esc(v.level) + '">' + esc(v.label) + '</span>' +
      lines + '</div>';
  }

  function opBlock() {
    var all = window.HnghOps.html(null);
    if (!all.feed) { // feed unavailable -> legacy digest bullets, verbatim
      return '<div class="ov-block"><span class="ops-title">For the operator</span>' +
        all.html + '</div>';
    }
    var open = window.HnghOps.html(function (it) { return it.status !== 'handled'; });
    var handled = window.HnghOps.html(function (it) { return it.status === 'handled'; });
    var body = open.html ||
      '<span class="ok-note">nothing flagged for the operator</span>';
    var counter = all.counter ? '<span class="ov-note">' + all.counter + '</span>' : '';
    var handledDetails = handled.html
      ? '<details><summary>handled (' + handled.html.split('class="opitem"').length - 1 + ')</summary>' +
        handled.html + '</details>'
      : '';
    return '<div class="ov-block"><span class="ops-title">For the operator</span>' +
      counter + body + handledDetails + '</div>';
  }

  function crumbsBlock(d) {
    var crumbs = (d && d.breadcrumbs) || [];
    var attn = crumbs.filter(function (c) {
      return /CRITICAL|NOTABLE|alert|failure/i.test(c.event || '');
    }).slice(-5).reverse(); // newest first
    if (!attn.length)
      return '<div class="ov-block"><span class="ops-title">Attention crumbs</span>' +
        '<span class="ok-note">no attention crumbs in the report stream</span></div>';
    var rows = attn.map(function (c) {
      var ev = c.event || '';
      return '<div class="crumb ' +
        (/CRITICAL|alert|failure/i.test(ev) ? 'alert' : 'notable') + '">' +
        '<span class="cts">' + esc(c.ts) + '</span>' +
        '<span class="cjob">' + esc(c.job) + '</span>' +
        '<span class="cevent">' + esc(ev) + '</span>' +
        '<span class="cdetail" title="' + esc(c.detail) + '">' + esc(c.detail) + '</span>' +
        '</div>';
    }).join('');
    return '<div class="ov-block"><span class="ops-title">Attention crumbs</span>' +
      rows + '</div>';
  }

  function dispatchBlock(d) {
    var txt = String((d && d.digest) || '');
    if (!txt)
      return '<div class="ov-block"><span class="ops-title">Today\'s dispatch</span>' +
        '<span class="ok-note">no digest content</span></div>';
    var lines = txt.split('\n');
    var excerpt = lines.slice(0, 30).join('\n');
    var today = new Date().toISOString().slice(0, 10);
    var url = '/digest/' + today + '.md';
    // probe-first (research-view discipline): render the link only when the
    // route answers 200 — never a dead first click. Route itself is another
    // beat's change; this view only fails closed.
    return '<div class="ov-block"><span class="ops-title">Today\'s dispatch</span>' +
      '<details class="ov-dispatch"><summary>excerpt — first ' +
      Math.min(30, lines.length) + ' of ' + lines.length + ' lines</summary>' +
      '<div class="md-body">' + window.HnghOps.md(excerpt) + '</div></details>' +
      '<span class="ov-dispatch-link"></span></div>';
  }

  /* ---- telemetry stat card (B7) ---- */
  var teleCache = null, teleAt = 0;
  function sparkline(buckets) {
    // zero-filled 24 hourly buckets ending now (server groups by
    // substr(ts,1,13) = "YYYY-MM-DDTHH"); flat zero line when no spend.
    var byHour = {}, max = 0, i, d, key;
    (buckets || []).forEach(function (b) { byHour[b.hour] = Number(b.spend) || 0; });
    var hours = [];
    for (i = 23; i >= 0; i--) {
      d = new Date(Date.now() - i * 3600000);
      d.setMinutes(0, 0, 0);
      key = d.toISOString().slice(0, 13);
      var s = byHour[key] || 0;
      if (s > max) max = s;
      hours.push(s);
    }
    if (!max) return '<span class="ov-note">no spend recorded in 24h</span>';
    var pts = hours.map(function (s, i2) {
      return (i2 / 23 * 100).toFixed(1) + ',' + (28 - s / max * 26).toFixed(1);
    }).join(' ');
    return '<svg class="ov-spark" width="120" height="30" viewBox="0 0 100 30"' +
      ' preserveAspectRatio="none" role="img" aria-label="24h spend sparkline">' +
      '<polyline points="' + pts + '" fill="none" stroke="var(--accent)" stroke-width="1.5"/>' +
      '</svg>';
  }
  function loadTele() {
    var host = root.querySelector('.ov-tele');
    if (!host) return;
    var note = host.querySelector('.ov-note');
    var draw = function (t) {
      teleCache = t; teleAt = Date.now();
      var runs = 0;
      (t.buckets || []).forEach(function (b) { runs += Number(b.runs) || 0; });
      note.innerHTML = '<span class="ov-tele-val">24h spend $' +
        Number(t.spend || 0).toFixed(2) + ' · ' + runs + ' calls</span>' +
        sparkline(t.buckets);
    };
    if (teleCache && Date.now() - teleAt < 30000) { draw(teleCache); return; }
    fetch('/telemetry.json', { cache: 'no-store' }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    }).then(draw).catch(function () {
      note.textContent = 'telemetry unavailable';
    });
  }

  function render() {
    if (!root || !window.HnghOps) return;
    var lr = window.HnghOps.data();
    var d = lr.d, spine = lr.spine;
    var html =
      verdictBlock(d, spine) +
      '<div class="ov-block ov-tele"><span class="ops-title">Spend</span>' +
      '<span class="ov-note">loading…</span></div>' +
      opBlock() +
      crumbsBlock(d) +
      dispatchBlock(d) +
      '<div class="ov-block ov-links">go: ' +
      '<a href="#tab-logs">Logs</a><a href="#tab-research">Research</a>' +
      '<a href="#tab-schedule">Schedule</a></div>';
    if (html === lastHtml) return; // poll churn must not collapse <details>
    lastHtml = html;
    root.innerHTML = html;
    loadTele(); // async fill: stat number + sparkline (30s client cache)
    var linkHost = root.querySelector('.ov-dispatch-link');
    var digestUrl = '/digest/' + new Date().toISOString().slice(0, 10) + '.md';
    fetch(digestUrl, { cache: 'no-store' }).then(function (r) {
      if (!r.ok || !linkHost.isConnected) return;
      var a = document.createElement('a');
      a.href = digestUrl;
      a.textContent = 'full dispatch';
      linkHost.appendChild(a);
    }).catch(function () { /* 404/network: no link, per fail-closed */ });
    var sum = document.getElementById('overview-sum');
    if (sum) {
      var ops = window.HnghOps.html(null);
      sum.textContent = ops.feed
        ? ops.open + ' open item' + (ops.open === 1 ? '' : 's') + ' · ' +
          ((d && d.breadcrumbs) || []).length + ' report entries'
        : 'operator feed unavailable';
    }
  }

  window.OverviewView = {
    init: function (el) {
      root = el;
      if (!document.getElementById('ov-style')) {
        var st = document.createElement('style');
        st.id = 'ov-style';
        st.textContent = STYLE;
        document.head.appendChild(st);
      }
      render();
      window.HnghOps.onOpChange(render);
    },
    refresh: function () { render(); }
  };
})();
