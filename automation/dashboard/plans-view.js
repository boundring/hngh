/* plans-view — the Plans tab: the operator's hngh state view (plan step 10
   + review B1 2026-09-11). Renders dashboard/plans.json (jobs/plan-feed.py)
   as two fact cards plus a plans table with search, status filter chips,
   newest-first sort, and a per-row link to the plan doc in the repo
   (docs/project/plans/<slug>.plan.md — target until the jailed P2 route).

   Filter state lives in module ui{} and only the <tbody> re-renders per
   keystroke/chip: input focus is never stolen and state survives refresh().
   Fail-closed per slot: a missing field renders a dim placeholder, never
   a fabricated value. Display layer only — never governance input. */
(function () {
  'use strict';

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fetchText(url, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 8000);
    return fetch(url, { cache: 'no-store', signal: ctrl.signal })
      .then(function (r) {
        clearTimeout(t);
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.text();
      });
  }
  function fetchJson(url, ms) {
    return fetchText(url, ms).then(function (t) { return JSON.parse(t); });
  }

  var root = null, feed = null;
  var ui = { q: '', status: '' }; // survives refresh(); only tbody re-renders
  var STATUSES = ['proposed', 'accepted', 'executing', 'executed', 'parked'];

  function visiblePlans() {
    var plans = (feed && Array.isArray(feed.plans)) ? feed.plans : [];
    var q = ui.q.trim().toLowerCase();
    return plans.filter(function (p) {
      if (ui.status && p.status !== ui.status) return false;
      if (q && String(p.slug || '').toLowerCase().indexOf(q) < 0) return false;
      return true;
    }).sort(function (a, b) {
      var ta = Date.parse(a.accepted) || 0, tb = Date.parse(b.accepted) || 0;
      if (tb !== ta) return tb - ta; // newest accepted first
      return String(a.slug || '').localeCompare(String(b.slug || ''));
    });
  }

  function renderFacts() {
    var qn = feed && feed.queue_next;
    var cer = feed && feed.last_ceremony_commit;
    return '<div class="pl-facts">'
      + '<div class="pl-fact"><span class="pl-label">queue next</span>'
      + '<span class="pl-value">' + (qn ? esc(qn) : '<span class="pl-none">unknown</span>') + '</span></div>'
      + '<div class="pl-fact"><span class="pl-label">last ceremony</span>'
      + '<span class="pl-value">'
      + (cer
          ? esc(cer.date) + ' <code>' + esc(String(cer.hash).slice(0, 12)) + '</code> '
            + '<span class="pl-subj">' + esc(cer.subject) + '</span>'
          : '<span class="pl-none">no ceremony commit found</span>')
      + '</span></div></div>';
  }

  function renderChips() {
    return ['all'].concat(STATUSES).map(function (s) {
      var val = s === 'all' ? '' : s;
      return '<button type="button" class="pl-chip" data-status="' + s + '"'
        + ' aria-pressed="' + String(ui.status === val) + '">' + s + '</button>';
    }).join('');
  }

  function renderRows() {
    var body = document.getElementById('plans-rows');
    if (!body) return;
    var rows = visiblePlans().map(function (p) {
      var doc = 'docs/project/plans/' + (p.slug || '') + '.plan.md'; // jailed P2 later
      return '<tr><td><a class="pl-link" href="' + esc(doc) + '"'
        + ' title="plan doc (repo path; jailed route is P2)">' + esc(p.slug) + '</a></td>'
        + '<td>' + esc(p.status) + '</td>'
        + '<td>' + esc(p.risk) + '</td>'
        + '<td>' + esc(p.accepted) + '</td>'
        + '<td>' + esc(p.steps_done) + '/' + esc(p.steps_total) + '</td></tr>';
    }).join('');
    body.innerHTML = rows ||
      '<tr><td colspan="5" class="pl-none">no plans match the active filters</td></tr>';
    var n = document.getElementById('plans-count');
    if (n) n.textContent = visiblePlans().length + ' of ' +
      ((feed && feed.plans) || []).length + ' plans';
  }

  function applyFilters() {
    Array.prototype.forEach.call(
      root.querySelectorAll('.pl-chip'), function (b) {
        b.setAttribute('aria-pressed',
          String(b.getAttribute('data-status') === (ui.status || 'all')));
      });
    renderRows(); // rows only: the search input keeps focus and value
  }

  window.PlansView = {
    init: function (el) {
      root = el;
      var st = document.createElement('style');
      st.id = 'plans-view-style';
      st.textContent = '.pl-facts{display:flex;gap:24px;flex-wrap:wrap;'
        + 'margin:4px 0 12px}.pl-fact{display:flex;flex-direction:column;gap:2px}'
        + '.pl-label{color:var(--muted);font-size:10.5px;letter-spacing:.05em;'
        + 'text-transform:uppercase}.pl-value{font-size:12.5px}'
        + '.pl-subj{color:var(--muted)}.pl-none{color:var(--dim)}'
        + '.pl-controls{display:flex;gap:6px;flex-wrap:wrap;align-items:center;'
        + 'margin:0 0 8px}.pl-chip{background:transparent;border:1px solid var(--line);'
        + 'color:var(--muted);font-size:11px;padding:1px 7px;cursor:pointer}'
        + '.pl-chip[aria-pressed="true"]{color:var(--ink);border-color:var(--accent);'
        + 'background:rgba(47,129,247,.12)}'
        + '.pl-search{background:var(--bg);border:1px solid var(--line);color:var(--ink);'
        + 'font-size:11.5px;padding:2px 6px;min-width:0;flex:1 1 120px}'
        + '.pl-count{color:var(--muted);font-size:11px}'
        + '.pl-link{color:var(--accent);text-decoration:none}'
        + '.pl-link:hover{text-decoration:underline}';
      document.head.appendChild(st);
      root.innerHTML = '<div id="pl-facts"></div>'
        + '<div class="pl-controls" role="group" aria-label="plan filters">'
        + '<input type="text" class="pl-search" id="pl-q" aria-label="search plans"'
        + ' placeholder="search slug…" value="' + esc(ui.q) + '">'
        + renderChips()
        + '<span class="pl-count" id="plans-count"></span></div>'
        + '<table><thead><tr><th>plan</th><th>status</th><th>risk</th>'
        + '<th>accepted</th><th>steps</th></tr></thead>'
        + '<tbody id="plans-rows"></tbody></table>';
      root.querySelector('#pl-q').addEventListener('input', function (ev) {
        ui.q = ev.target.value; renderRows(); // rows-only: focus kept
      });
      Array.prototype.forEach.call(
        root.querySelectorAll('.pl-chip'), function (b) {
          b.addEventListener('click', function () {
            var s = b.getAttribute('data-status');
            ui.status = (s === 'all') ? '' : s;
            applyFilters();
          });
        });
      this.refresh();
    },
    refresh: function () {
      if (!root) return;
      fetchJson('plans.json')
        .then(function (f) {
          feed = f;
          var facts = document.getElementById('pl-facts');
          if (facts) facts.innerHTML = renderFacts();
          renderRows();
          var sum = document.getElementById('plans-sum');
          if (sum) sum.textContent = ((feed && feed.plans) || []).length
            + ' plans · feed ' + (feed.generated || '?');
        })
        .catch(function () {
          root.innerHTML = '<div class="placeholder">plans feed unavailable</div>';
        });
    }
  };
})();
