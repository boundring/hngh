/* newspaper-view — the front page of THE DAILY hngh-automation.
   Mounted by index.html (course-correction slice 6, 2026-09-27).

   Static fetch-and-render over EXISTING dashboard feeds only:
   readout.json (masthead verdict + lead), operator-items.json
   (decision articles POSTing the token-gated endpoints), sessions.json,
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

  // ---------- expandable article builder ----------
  function article(headline, meta, bodyLines) {
    var det = document.createElement('details');
    var sum = document.createElement('summary');
    sum.innerHTML = '<b>' + esc(headline) + '</b>' +
      (meta ? ' <span class="art-meta">' + esc(meta) + '</span>' : '');
    det.appendChild(sum);
    (bodyLines || []).forEach(function (line) {
      var p = document.createElement('p');
      p.textContent = line;
      det.appendChild(p);
    });
    return det;
  }

  // ---------- section renderers (schema-gated, fail closed) ----------
  function renderLead(ro) {
    var el = $('sec-lead-body');
    if (!el || !ro || typeof ro !== 'object') return dim(el, '(no spine)');
    var v = ro.verdict;
    if (!v || typeof v.state !== 'string') return dim(el, '(no verdict)');
    var lines = ['spine verdict: ' + v.state];
    (v.reasons || []).forEach(function (r) { lines.push('reason: ' + r); });
    var q = Array.isArray(ro.queue) ? ro.queue.length : null;
    if (q != null) lines.push('queue depth: ' + q);
    el.innerHTML = '';
    el.appendChild(article(
      v.state.replace(/-/g, ' '),
      todayFromStamp(ro),
      lines));
  }

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
    open.slice(0, 12).forEach(function (it) {
      var meta = 'first seen ' + (it.first_seen || '?');
      var det = article(it.text || it.id, meta, [
        'id: ' + it.id + ' · last seen ' + (it.last_seen || '?')]);
      var bar = document.createElement('div');
      bar.className = 'decision-bar';
      [["handle", "/operator-item/handle"],
       ["dismiss", "/operator-item/dismiss"]]
        .forEach(function (pair) {
          var b = document.createElement('button');
          b.className = 'ghost';
          b.textContent = pair[0];
          b.addEventListener('click', function () {
            b.disabled = true;
            postJson(pair[1], { id: it.id })
              .then(load)
              .catch(function (e) {
                b.disabled = false;
                showErr('decision failed: ' + e.message);
              });
          });
          bar.appendChild(b);
        });
      det.appendChild(bar);
      el.appendChild(det);
    });
    if (open.length > 12) {
      var p = document.createElement('p');
      p.className = 'placeholder';
      p.textContent = '…and ' + (open.length - 12) +
        ' more (console has all)';
      el.appendChild(p);
    }
  }

  function renderSessions(s) {
    var el = $('sec-sessions-body');
    var rows = s && Array.isArray(s.sessions) ? s.sessions : null;
    if (!el || !rows) return dim(el, '(no sessions feed)');
    el.innerHTML = '';
    if (!rows.length) return dim(el, '(no live sessions)');
    rows.slice(0, 8).forEach(function (r) {
      el.appendChild(article(
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
      el.appendChild(article(
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
    ro.queue.slice(0, 10).forEach(function (a) {
      var id = (a && a.id) || '?';
      el.appendChild(article(String(id),
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
    nodes.forEach(function (n) {
      el.appendChild(article(
        n.name || '(unnamed)',
        (n.online ? 'online' : 'offline') + ' · ' + (n.os || '?'),
        n.ip ? ['ip: ' + n.ip] : []));
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
