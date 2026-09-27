/* newspaper-view — the front page of THE DAILY hngh-automation. v2.
   Mounted by index.html (course-correction slice 6; v2 rebuild 09-27).

   v2 doctrine: the paper READS like a paper. Articles print open with
   real body text — no wall of collapsed disclosure bars. Operator
   decisions are editorial cards: each choice shows its predicted
   outcome BEFORE the operator commits, and identical junk (the
   "[feedback:idea] from email" test-artifact flood, root-caused
   2026-09-27 to an unseamed FEEDBACK dir in test-dashboard-p1.py)
   collapses into ONE family card instead of 40 identical rows.

   Static fetch-and-render over EXISTING dashboard feeds only:
   readout.json (masthead verdict + lead + alerts), operator-items.json
   (decision cards POSTing the token-gated endpoints), sessions.json,
   research-routes.json, fleet.json. Page-turn = CSS scroll-snap +
   arrow keys / buttons. Refresh ONLY via HnghPoll or the refresh
   button — raw timer loops are test-banned (poll-hygiene contract).

   Honesty rules (story-view pattern): the masthead date is the feed's
   own `generated` stamp, never a client-prayed Date; every rendered
   string passes esc(); an unreachable or malformed feed renders a
   literal error banner, never a fabricated article. */
(function () {
  'use strict';

  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;',
               '"': '&quot;', "'": '&#39;' }[c];
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

  // ---------- fail-closed banner ----------
  // element id "papererr": the literal error banner, never half a page
  function showErr(msg) {
    var b = document.getElementById("papererr");
    if (!b) return;
    b.hidden = false;
    b.textContent = 'the press is stalled: ' + msg;
  }
  function dim(el, text) {
    el.innerHTML = '';
    var d = document.createElement('div');
    d.className = 'placeholder';
    d.textContent = text || '(nothing to print)';
    el.appendChild(d);
  }

  // ---------- bounded fetches (story-view pattern) ----------
  function fetchText(url, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 8000);
    return fetch(url, { cache: 'no-store', signal: ctrl.signal })
      .then(function (r) {
        clearTimeout(t);
        if (!r.ok) throw new Error(url + ' HTTP ' + r.status);
        return r.text();
      })
      .catch(function (e) { clearTimeout(t); throw e; });
  }
  function fetchJSON(url, ms) {
    return fetchText(url, ms).then(function (s) {
      return JSON.parse(s); // parse errors count as feed failure
    });
  }

  // ---------- token plumbing (app.js pattern) ----------
  function hnghToken() {
    var m = document.querySelector('meta[name="hngh-token"]');
    return m ? (m.getAttribute('content') || '') : '';
  }
  function tokenExpiredChip() {
    if (document.getElementById('hngh-expired')) return;
    var d = document.createElement('div');
    d.id = 'hngh-expired';
    d.style.cssText = 'position:fixed;right:10px;bottom:10px;z-index:99;' +
      'background:var(--panel);color:var(--warn);' +
      'border:1px solid var(--warn);padding:6px 10px;font-size:12px';
    d.innerHTML = 'session expired — <button class="ghost" ' +
      'id="hngh-expired-reload">reload</button>';
    document.body.appendChild(d);
    document.getElementById('hngh-expired-reload')
      .addEventListener('click', function () { location.reload(); });
  }
  function postJson(url, body, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 8000);
    return fetch(url, {
      method: 'POST', cache: 'no-store', signal: ctrl.signal,
      headers: { 'Content-Type': 'application/json',
                 'X-Hngh-Token': hnghToken() },
      body: JSON.stringify(body || {})
    }).then(function (r) {
      clearTimeout(t);
      if (r.status === 403) tokenExpiredChip();
      return r.json().catch(function () { return {}; })
        .then(function (j) {
          if (!r.ok) throw new Error(j.error || ('HTTP ' + r.status));
          return j;
        });
    }).catch(function (e) { clearTimeout(t); throw e; });
  }

  // ---------- masthead date: feed's own stamp, never Date() ----------
  function todayFromStamp(feed) {
    var g = feed && feed.generated;
    return (typeof g === 'string' && g.length >= 10) ? g.slice(0, 10) : '';
  }

  // ---------- article builder: PRINTS OPEN ----------
  // Every story ships open (details[open]) with a kicker, headline,
  // deck line, and visible body paragraphs. A newspaper does not make
  // you click forty triangles to read it.
  function article(kicker, headline, deck, bodyLines) {
    var det = document.createElement('details');
    det.open = true;
    det.className = 'art';
    var sum = document.createElement('summary');
    sum.innerHTML =
      (kicker ? '<div class="kicker">' + esc(kicker) + '</div>' : '') +
      '<b class="headline">' + esc(headline) + '</b>' +
      (deck ? ' <span class="art-meta">' + esc(deck) + '</span>' : '');
    det.appendChild(sum);
    (bodyLines || []).forEach(function (line) {
      var p = document.createElement('p');
      p.textContent = line;
      det.appendChild(p);
    });
    return det;
  }

  // ---------- decision card: choices with outcome previews ----------
  // choices: [{label, outcome, run(btnDone, progress)}]. The outcome
  // line prints UNDER each button before any click — the operator
  // always sees what a choice does before taking it.
  function decisionCard(kicker, headline, deck, bodyLines, choices) {
    var card = article(kicker, headline, deck, bodyLines);
    var bar = document.createElement('div');
    bar.className = 'decision-bar';
    var progress = document.createElement('div');
    progress.className = 'choice-progress';
    choices.forEach(function (ch) {
      var row = document.createElement('div');
      row.className = 'choice-row';
      var b = document.createElement('button');
      b.className = 'choice';
      b.textContent = ch.label;
      var out = document.createElement('div');
      out.className = 'outcome';
      out.textContent = ch.outcome;
      b.addEventListener('click', function () {
        b.disabled = true;
        Promise.resolve(ch.run(btnDone, progress))
          .catch(function (e) {
            btnDone(false);
            showErr('decision failed: ' + e.message);
          });
        function btnDone(reenable) { b.disabled = false; void reenable; }
      });
      row.appendChild(b);
      row.appendChild(out);
      bar.appendChild(row);
    });
    card.appendChild(bar);
    card.appendChild(progress);
    return card;
  }

  function postItem(endpoint, id) {
    return postJson(endpoint, { id: id });
  }

  // ---------- section renderers (schema-gated, fail closed) ----------
  function renderLead(ro) {
    var el = $('sec-lead-body');
    if (!el || !ro || typeof ro !== 'object') return dim(el, '(no spine)');
    var v = ro.verdict;
    if (!v || typeof v.state !== 'string') return dim(el, '(no verdict)');
    var q = Array.isArray(ro.queue) ? ro.queue.length : null;
    var deck = todayFromStamp(ro) +
      (q != null ? ' · report queue depth ' + q : '') +
      ' · by the spine desk';
    var lines = (v.reasons || []).map(function (r) {
      return 'Because: ' + r;
    });
    if (!lines.length) lines = ['No reasons were given; the spine is silent.'];
    lines.push('Full queue detail: the Alerts sheet and the console.');
    el.innerHTML = '';
    el.appendChild(article('the spine desk',
      v.state.replace(/-/g, ' '), deck, lines));
  }

  // The empty-idea flood family: every "[feedback:idea] from email"
  // item is the same test-artifact (root cause 2026-09-27: unseamed
  // ds.FEEDBACK in automation/tests/test-dashboard-p1.py leaked one
  // capture per make-test run since 09-11). 40 rows of it are not 40
  // decisions — they are one decision, printed once.
  // item text arrives alert_row-formatted ("job | kind | payload"),
  // so the family matcher matches the payload anywhere in the text
  var FLOOD_NEEDLE = "[feedback:idea] from email";
  function isFlood(it) {
    return String(it && it.text || "").indexOf(FLOOD_NEEDLE) !== -1;
  }
  var FLOOD_MAX_DISMISS = 80;

  function renderDecisions(oi) {
    var el = $('sec-decisions-body');
    var items = oi && typeof oi === 'object' && Array.isArray(oi.items)
      ? oi.items : (Array.isArray(oi) ? oi : null);
    if (!el || !items) return dim(el, '(no operator items feed)');
    var open = items.filter(function (it) {
      return it && it.status === 'open' && it.id;
    });
    if (!open.length) return dim(el, '(no open decisions)');
    el.innerHTML = '';

    var flood = open.filter(isFlood);
    var rest = open.filter(function (it) { return !isFlood(it); });

    if (flood.length) {
      el.appendChild(floodCard(flood));
    }

    rest.slice(0, 12).forEach(function (it) {
      el.appendChild(decisionCard('operator decision',
        it.text || it.id,
        'first seen ' + (it.first_seen || '?') +
        ' · last seen ' + (it.last_seen || '?'),
        ['id: ' + it.id],
        [{ label: 'Handle',
           outcome: 'Marks the item handled (operator-approved.json) — ' +
             'it leaves the open feed as acknowledged work.',
           run: function () {
             return postItem("/operator-item/handle", it.id)
               .then(function () { load(); });
           } },
         { label: 'Dismiss',
           outcome: 'Moves the item to operator-dismissed.json — it ' +
             'leaves the feed without action.',
           run: function () {
             return postItem("/operator-item/dismiss", it.id)
               .then(function () { load(); });
           } }]));
    });
    if (rest.length > 12) {
      var p = document.createElement('p');
      p.className = 'placeholder';
      p.textContent = '…and ' + (rest.length - 12) +
        ' more (console has all)';
      el.appendChild(p);
    }
  }

  // The flood card: one editorial decision for the whole family.
  function floodCard(flood) {
    var n = flood.length;
    return decisionCard('operator decision · the flood file',
      'The empty-idea flood (' + n + ' items)',
      'one story, ' + n + ' copies · filed by the test suite',
      ['All ' + n + ' rows carry the same payload: the literal test ' +
       'string "from email", filed by test-dashboard-p1.py through an ' +
       'unseamed FEEDBACK dir, one capture per make-test run since ' +
       '09-11. The leak is fixed (2026-09-27); these rows are its ' +
       'residue. Verified: zero operator content in any of them.'],
      [{ label: 'Dismiss all ' + n,
         outcome: 'Moves all ' + n + ' rows to operator-dismissed.json. ' +
           'The Decisions sheet clears. Nothing of value is lost — ' +
           'every payload is the same empty test string.',
         run: function (btnDone, progress) {
           var ids = flood.map(function (it) { return it.id; });
           var total = Math.min(ids.length, FLOOD_MAX_DISMISS);
           var done = 0;
           return ids.slice(0, FLOOD_MAX_DISMISS)
             .reduce(function (chain, id) {
               return chain.then(function () {
                 return postItem('/operator-item/dismiss', id)
                   .then(function () {
                     done += 1;
                     progress.textContent =
                       'dismissed ' + done + ' of ' + total + '…';
                   });
               });
             }, Promise.resolve()).then(function () {
               btnDone(false);
               load();
             });
         } },
       { label: 'Keep them',
         outcome: 'No change. The rows stay on the feed; this card ' +
           'returns in the next edition.',
         run: function () { /* deliberate no-op */ } }]);
  }

  function renderSessions(s) {
    var el = $('sec-sessions-body');
    var rows = s && Array.isArray(s.sessions) ? s.sessions : null;
    if (!el || !rows) return dim(el, '(no sessions feed)');
    el.innerHTML = '';
    if (!rows.length) return dim(el, '(no live sessions)');
    rows.slice(0, 8).forEach(function (r) {
      el.appendChild(article('sessions',
        r.mission || r.title_full || r.title || r.id,
        (r.state || '?') + ' · ' + fmtAge(r.age),
        ['id: ' + r.id + ' · source: ' + (r.source || '?')]));
    });
  }

  function renderResearch(rr) {
    var el = $('sec-research-body');
    var routes = rr && Array.isArray(rr.routes) ? rr.routes : null;
    if (!el || !routes) return dim(el, '(no routes feed)');
    el.innerHTML = '';
    if (!routes.length) return dim(el, '(no routes yet)');
    routes.slice(0, 10).forEach(function (r) {
      var t = r.terminus && typeof r.terminus === 'object'
        ? r.terminus : {};
      el.appendChild(article('research desk',
        r.title || r.id,
        (r.status || '?') + (t.date ? ' · ' + t.date : ''),
        ['id: ' + r.id + ' · terminus: ' + (t.action || '?') +
         (r.harvested ? ' · harvested' : '')]));
    });
  }

  function renderAlerts(ro) {
    var el = $('sec-alerts-body');
    if (!el || !ro || typeof ro !== 'object' || !Array.isArray(ro.queue))
      return dim(el, '(no readout feed)');
    el.innerHTML = '';
    if (!ro.queue.length) return dim(el, '(queue clear)');
    el.appendChild(article('alerts desk',
      'How to read the queue', 'status glossary',
      ['queued = waiting for a lane or an operator call. ' +
       'done = closed, kept for the record. ' +
       'acked = seen by the operator, no action planned.']));
    ro.queue.slice(0, 10).forEach(function (a) {
      var id = (a && a.id) || '?';
      el.appendChild(article('alerts desk',
        String(id),
        a && a.status != null ? String(a.status) : '?',
        ['queue entry: ' + id]));
    });
  }

  function renderSystem(fl) {
    var el = $('sec-system-body');
    var nodes = fl && Array.isArray(fl.nodes) ? fl.nodes : null;
    if (!el || !nodes) return dim(el, '(no fleet feed)');
    el.innerHTML = '';
    if (!nodes.length) return dim(el, '(fleet empty)');
    // Honest naming: fleet-manager currently emits name "?" for peers
    // whose tailscaled serializes PascalCase fields it does not read
    // (kernel-surface fix pending); print the truth, not a broken "?".
    nodes.forEach(function (n) {
      var named = n.name && n.name !== '?';
      el.appendChild(article('system desk',
        named ? n.name : 'mesh node (name unresolved)',
        (n.online ? 'online' : 'offline') + ' · ' + (n.os || '?'),
        [n.ip ? 'mesh ip: ' + n.ip
              : 'no mesh address reported.',
         named ? '' :
           'peer names are unresolved in the feed itself ' +
           '(fleet-manager field-casing fix pending on the kernel ' +
           'lane); the node is real, the label is not.'].filter(Boolean)));
    });
  }

  // ---------- load + refresh (HnghPoll only) ----------
  function load() {
    return Promise.allSettled([
      fetchJSON("readout.json"),
      fetchJSON("operator-items.json"),
      fetchJSON("sessions.json"),
      fetchJSON("research-routes.json"),
      fetchJSON("fleet.json")
    ]).then(function (rs) {
      renderLead(rs[0].status === 'fulfilled' ? rs[0].value : null);
      renderDecisions(rs[1].status === 'fulfilled' ? rs[1].value : null);
      renderSessions(rs[2].status === 'fulfilled' ? rs[2].value : null);
      renderResearch(rs[3].status === 'fulfilled' ? rs[3].value : null);
      renderSystem(rs[4].status === 'fulfilled' ? rs[4].value : null);
      // alerts share readout.json with the lead
      renderAlerts(rs[0].status === 'fulfilled' ? rs[0].value : null);
      if (rs[0].status === 'fulfilled') {
        var ro = rs[0].value;
        var mast = $('paper-verdict');
        if (mast && ro && ro.verdict)
          mast.textContent = ro.verdict.state || '…';
        var dat = $('paper-date');
        var day = todayFromStamp(ro);
        if (dat && day) dat.textContent = day;
      }
    }).catch(function (e) { showErr(e.message); });
  }

  // ---------- page turn ----------
  var paper = null;
  function sheetEls() {
    return Array.prototype.slice.call(
      document.querySelectorAll('#paper > section.sheet'));
  }
  function turn(dir) {
    var sheets = sheetEls();
    if (!sheets.length) return;
    var x = paper.scrollLeft;
    var offs = sheets.map(function (s) { return s.offsetLeft; });
    var target = dir > 0
      ? offs.find(function (o) { return o > x + 10; })
      : offs.slice().reverse().find(function (o) { return o < x - 10; });
    paper.scrollTo({ left: (target == null ? 0 : target),
                     behavior: 'smooth' });
  }

  function init() {
    paper = $('paper');
    $('paper-next').addEventListener('click', function () { turn(1); });
    $('paper-prev').addEventListener('click', function () { turn(-1); });
    $('paper-refresh').addEventListener('click', function () { load(); });
    document.addEventListener('keydown', function (ev) {
      if (ev.key === 'ArrowRight') turn(1);
      else if (ev.key === 'ArrowLeft') turn(-1);
    });
    // section menu: one link per sheet
    var menu = $('paper-menu');
    sheetEls().forEach(function (s) {
      var a = document.createElement('a');
      a.className = 'ghost';
      a.href = '#' + s.id;
      a.textContent = s.id.replace(/^sec-/, '');
      menu.appendChild(a);
    });
    // HnghPoll lives in app.js (console-only); the newspaper ships its
    // own equivalent: setTimeout chain, paused while hidden, backoff
    // on failure, reset on success — raw timer loops stay banned.
    if (window.HnghPoll && window.HnghPoll.start)
      window.HnghPoll.start(load, { interval: 30000 });
    else {
      var base = 30000, delay = base, t = null;
      function clear() { if (t) { clearTimeout(t); t = null; } }
      function tick() {
        if (document.hidden) return;
        Promise.resolve(load()).then(function () {
          delay = base; t = setTimeout(tick, delay);
        }, function () {
          delay = Math.min(delay * 2, 60000);
          t = setTimeout(tick, delay);
        });
      }
      document.addEventListener('visibilitychange', function () {
        if (document.hidden) clear(); else tick();
      });
      tick();
    }
  }

  if (document.readyState === 'loading')
    document.addEventListener('DOMContentLoaded', init);
  else init();
})();
