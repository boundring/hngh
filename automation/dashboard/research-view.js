/* research-view — the Research tab's alternation-cycle view, mounted into
   index.html#p-research > #research-root by app.js (window.ResearchView =
   {init, refresh}; init on first tab activation, refresh() on later ones,
   plus its own 60s poll). Renders dashboard/research.json
   (jobs/research-feed.py) as four cards:

   · alternation state — the master-plan DesignPlan facet made visible: a
     big verdict ('research beat due' / 'grow beat due' / 'balanced') with
     the last grow beat (newest hngh commit) and last research beat (newest
     docs/research|design mtime) beside it.
   · campaign board — ONE card for every lines[] row plus the backlog
     proposals, under a single state filter chip row: proposed (backlog
     lanes) / planned / expanding / crystallized / reviewed (the descent
     spine's dispositions ledger marks crystallized lines reviewed). The
     old separate research-lanes card duplicated the board's lines and is
     gone.
   · design docs — every docs/design/*.md with its first Status: line.
   · open questions — bullets from the docs' '## Open questions' sections,
     collapsed per doc inside a native <details>.
   · lessons — llm-wiki source count plus the 3 newest source filenames.

   Operator controls (advisory/organizational only): an 'add research
   line' form (POST /research-line — appends a proposal-ready lane to the
   hngh backlog) and a per-lane 'note' button (POST /research-note —
   backlog annotation, optionally an alert-row steer). Both are prose
   writes for the operator to read and rotate; NEVER governance input.
   Fail-closed per source: a feed slot that came back as an error renders
   an inline note instead of the card body; the other cards still render.
   All styles are injected here in one owned
   <style> tag (rs- prefix) — style.css is not touched. Display layer only —
   never governance input. */
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
  function postJson(url, body, ms) {
    // token-guarded shared POST (P1): the header + the 403 expired chip
    // live in app.js; this view only names the route and body.
    return window.HnghOps.post(url, body, ms);
  }
  function ago(ts) {
    var t = Date.parse(ts);
    if (isNaN(t)) return String(ts || '?');
    var s = (Date.now() - t) / 1000;
    if (s < 0) s = 0;
    if (s < 90) return Math.round(s) + 's ago';
    if (s < 5400) return Math.round(s / 60) + 'm ago';
    if (s < 172800) return (Math.round(s / 3600 * 10) / 10) + 'h ago';
    return Math.round(s / 86400) + 'd ago';
  }

  /* ---- owned styles (rs- prefix) ---- */
  var STYLE = [
    '.rs-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));',
    '  gap:10px;align-items:start}',
    '.rs-card{background:var(--panel);border:1px solid var(--line);border-radius:0;',
    '  padding:10px 12px;min-width:0}',
    '.rs-title{font-size:11px;letter-spacing:.08em;text-transform:uppercase;',
    '  color:var(--muted);margin:0 0 8px}',
    '.rs-alt{grid-column:1/-1;display:flex;gap:18px;align-items:baseline;flex-wrap:wrap;',
    '  border-left:3px solid var(--accent)}',
    '.rs-verdict{font-size:20px;font-weight:600;letter-spacing:.01em}',
    '.rs-verdict.balanced{color:var(--ok)}',
    '.rs-verdict.due{color:var(--accent)}',
    '.rs-verdict.none{color:var(--muted);font-size:15px}',
    '.rs-beats{display:flex;gap:16px;flex-wrap:wrap;color:var(--muted);font-size:12px}',
    '.rs-beats b{color:var(--ink);font-weight:500}',
    '.rs-lane{padding:6px 0;border-top:1px solid var(--line)}',
    '.rs-lane:first-of-type{border-top:0}',
    '.rs-lane .nm{font-weight:500;font-size:13px}',
    '.rs-lane .pb{color:var(--muted);font-size:12px;margin-top:2px}',
    '.rs-doc{display:flex;gap:8px;align-items:baseline;padding:3px 0;font-size:12.5px}',
    '.rs-doc .nm{white-space:nowrap;font-weight:500}',
    '.rs-doc .st{color:var(--muted);font-size:11.5px;min-width:0;overflow:hidden;',
    '  text-overflow:ellipsis;white-space:nowrap}',
    '.rs-doc .st.un{color:var(--warn)}',
    '.rs-q details{border-top:1px solid var(--line);padding:3px 0}',
    '.rs-q details:first-of-type{border-top:0}',
    '.rs-q summary{cursor:pointer;font-size:12.5px;font-weight:500;list-style:none}',
    '.rs-q summary::before{content:"+ ";color:var(--accent)}',
    '.rs-q details[open] summary::before{content:"− "}',
    '.rs-q li{color:var(--muted);font-size:12px;margin:4px 0 4px 2px}',
    '.rs-q ul{margin:4px 0 6px;padding-left:16px}',
    '.rs-lessons .num{font-size:22px;font-weight:600;color:var(--accent)}',
    '.rs-lessons .lbl{color:var(--muted);font-size:11.5px;margin-left:6px}',
    '.rs-lessons ul{margin:8px 0 0;padding-left:16px;color:var(--muted);font-size:12px}',
    '.rs-note{color:var(--warn);font-size:12px}',
    '.rs-form{display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin:6px 0}',
    '.rs-form input[type=text]{flex:1;min-width:140px;background:var(--bg);',
    '  border:1px solid var(--line);border-radius:0;color:var(--ink);',
    '  padding:4px 8px;font-size:12.5px}',
    '.rs-btn{background:var(--bg);border:1px solid var(--line);border-radius:0;',
    '  color:var(--ink);padding:3px 10px;font-size:12px;cursor:pointer}',
    '.rs-btn:hover{border-color:var(--accent)}',
    '.rs-btn.rs-notebtn{padding:0 7px;font-size:11px;color:var(--muted)}',
    '.rs-chk{color:var(--muted);font-size:12px;display:flex;gap:4px;align-items:center}',
    '.rs-result{font-size:12px;margin:4px 0}',
    '.rs-result.ok{color:var(--ok)}',
    '.rs-result.err{color:var(--warn)}',
    '.rs-foot{color:var(--dim);font-size:11px;margin-top:8px}',
    '@media (max-width:760px){.rs-grid{grid-template-columns:1fr}}',
    /* campaign board (research-page-spec §2): one column per state */
    '.rsb-board{grid-column:1/-1}',
    '.rsb-cols{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));',
    '  gap:10px;align-items:start}',
    '.rsb-col{min-width:0}',
    '.rsb-head{font-size:11px;letter-spacing:.08em;text-transform:uppercase;',
    '  color:var(--muted);margin:0 0 6px;display:flex;gap:6px;align-items:baseline}',
    '.rsb-head .rsb-n{color:var(--ink)}',
    '.rsb-head.planned{border-left:3px solid var(--muted);padding-left:8px}',
    '.rsb-head.proposed{border-left:3px solid var(--muted);padding-left:8px}',
    '.rsb-head.expanding{border-left:3px solid var(--accent);padding-left:8px}',
    '.rsb-head.crystallized{border-left:3px solid var(--ok);padding-left:8px}',
    '.rsb-head.reviewed{border-left:3px solid var(--ok);padding-left:8px}',
    '.rsb-card{margin:0 0 6px}',
    '.rsb-card .nm{font-size:12.5px;font-weight:500}',
    '.rsb-card .rsb-sub{color:var(--muted);font-size:11px;margin-top:2px;',
    '  overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    '.rsb-card a{color:var(--accent);font-size:11.5px}',
    '.rsb-empty{color:var(--dim);font-size:11.5px}',
    '.rsb-chips{display:flex;gap:6px;flex-wrap:wrap;margin:6px 0}',
    '@media (max-width:760px){.rsb-cols{grid-template-columns:1fr}}'
  ].join('\n');

  /* ---- state ---- */
  var root = null, timer = null, feed = null;
  var addResult = null, openLane = null, laneResult = null;
  var stateFilter = ''; // board chip filter; '' shows every state column
  // crystallized result-doc probes (research-page-spec §2): filename derived
  // from the line's id + updated date only — never parsed from contents.
  // name -> true when the doc probe succeeded; absent/false = no link.
  var docLinks = {};
  function docLink(l) {
    var date = String(l.updated || '').slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !l.id) return '';
    var name = date + '-' + l.id + '.md'; // <date>-<id>.md convention
    if (!/^[A-Za-z0-9][A-Za-z0-9 _.-]*\.md$/.test(name)) return '';
    if (docLinks[name]) return 'hngh-docs/research/' + encodeURIComponent(name);
    return ''; // probed-absent or not yet probed: fail closed, no dead link
  }
  function probeDocs(lines) {
    var pending = 0;
    (Array.isArray(lines) ? lines : []).forEach(function (l) {
      if (!l || (l.state !== 'crystallized' && l.state !== 'reviewed')) return;
      var date = String(l.updated || '').slice(0, 10);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !l.id) return;
      var name = date + '-' + l.id + '.md';
      if (!/^[A-Za-z0-9][A-Za-z0-9 _.-]*\.md$/.test(name) || name in docLinks) return;
      docLinks[name] = false;
      pending++;
      fetch('hngh-docs/research/' + encodeURIComponent(name), { cache: 'no-store' })
        .then(function (r) { if (r.ok) docLinks[name] = true; })
        .catch(function () { /* absent stays absent */ })
        .then(function () {
          if (--pending === 0) {
            var draft = document.querySelector('#rs-addline input');
            if (openLane === null && !(draft && draft.value)) render();
          }
        });
    });
  }

  function note(msg) {
    return '<div class="rs-note">' + esc(msg) + '</div>';
  }

  /* ---- card renderers ---- */

  function altCard(a) {
    if (!a) return '';
    var verdict, cls;
    if (a.error) return note('alternation: ' + a.error);
    if (a.due === 'balanced') { verdict = 'balanced'; cls = 'balanced'; }
    else if (a.due === 'research') { verdict = 'research beat due'; cls = 'due'; }
    else if (a.due === 'grow') { verdict = 'grow beat due'; cls = 'due'; }
    else { verdict = a.errors && a.errors.length ? a.errors[0] : 'alternation unknown'; cls = 'none'; }
    return '<section class="rs-card rs-alt">' +
      '<div class="rs-verdict ' + cls + '">' + esc(verdict) + '</div>' +
      '<div class="rs-beats">' +
      '<span>last grow <b title="' + esc(a.last_grow || '') + '">' +
      (a.last_grow ? esc(ago(a.last_grow)) : '?') + '</b></span>' +
      '<span>last research <b title="' + esc(a.last_research || '') + '">' +
      (a.last_research ? esc(ago(a.last_research)) : '?') + '</b></span>' +
      '</div></section>';
  }

  /* ---- campaign board: one card per lines[] row PLUS the backlog
     proposals (the old research-lanes card, folded in as the 'proposed'
     state) — one state filter chip row above the columns. ---- */
  function boardSection(lines, lanes) {
    if (!Array.isArray(lines)) {
      return note(lines && lines.error ? lines.error : 'lines feed unavailable');
    }
    var cols = { proposed: [], planned: [], expanding: [], crystallized: [], reviewed: [] };
    var unknown = 0;
    (Array.isArray(lanes) ? lanes : []).forEach(function (l) {
      if (l) cols.proposed.push(l);
    });
    lines.forEach(function (l) {
      if (l && cols[l.state]) cols[l.state].push(l); else unknown++;
    });
    var chips = Object.keys(cols).map(function (st) {
      return '<button type="button" class="cf-chip rs-state" data-state="' + st + '"' +
        ' aria-pressed="' + (stateFilter === st) + '" title="filter the board by state">' +
        st + ' ' + cols[st].length + '</button>';
    }).join('');
    var inner = Object.keys(cols)
      .filter(function (st) { return !stateFilter || stateFilter === st; })
      .map(function (st) {
        var cards = cols[st].length
          ? cols[st].map(function (l) { return st === 'proposed' ? laneRow(l) : lineCard(l, st); }).join('')
          : '<div class="rsb-empty">empty</div>';
        return '<div class="rsb-col"><h4 class="rsb-head ' + st + '">' + st +
          ' <span class="rsb-n">' + cols[st].length + '</span></h4>' + cards + '</div>';
      }).join('');
    return '<section class="rs-card rsb-board">' +
      '<h3 class="rs-title">Campaign board</h3>' +
      '<form class="rs-form" id="rs-addline">' +
      '<input type="text" name="lane" placeholder="new lane name" maxlength="64" required>' +
      '<input type="text" name="intent" placeholder="problem / intent" maxlength="500" required>' +
      '<button class="rs-btn" type="submit">add line</button></form>' +
      result(addResult) +
      '<div class="rsb-chips" role="group" aria-label="filter the board by state">' + chips + '</div>' +
      '<div class="rsb-cols">' + inner + '</div>' +
      (unknown ? '<div class="rs-note">' + unknown +
        ' line(s) with a state outside proposed/planned/expanding/crystallized/reviewed not rendered — the board invents no extra state</div>' : '') +
      result(laneResult) + '</section>';
  }

  /* ---- board card per line ---- */
  function lineCard(l, st) {
    var updated = String(l.updated || '');
    var link = '';
    if (st === 'crystallized' || st === 'reviewed') {
      var url = docLink(l);
      if (url) link = '<div class="rsb-sub"><a href="' + esc(url) +
        '" target="_blank" rel="noopener">result doc</a></div>';
    }
    return '<section class="rs-card rsb-card">' +
      '<div class="nm">' + esc(l.line || l.id || '?') + '</div>' +
      '<div class="rsb-sub">' + esc(l.id || '') +
      (updated ? ' · <span title="' + esc(updated) + '">' + esc(ago(updated)) + '</span>' : '') +
      '</div>' + link + '</section>';
  }
  function result(r) {
    return r ? '<div class="rs-result ' + (r.ok ? 'ok' : 'err') + '">' +
      esc(r.msg) + '</div>' : '';
  }

  function laneRow(l) {
    var html = '<div class="rs-lane"><div class="nm">' + esc(l.name) +
      ' <button class="rs-btn rs-notebtn" type="button" data-lane="' + esc(l.name) +
      '">note</button></div>' +
      (l.problem ? '<div class="pb">' + esc(l.problem) + '</div>' : '');
    if (openLane === l.name) {
      html += '<form class="rs-form rs-noteform" data-lane="' + esc(l.name) + '">' +
        '<input type="text" name="note" placeholder="note (3-300 chars)" maxlength="300" required>' +
        '<label class="rs-chk"><input type="checkbox" name="affecting">affecting</label>' +
        '<button class="rs-btn" type="submit">send</button>' +
        '<button class="rs-btn" type="button" data-cancel="1">x</button></form>' +
        '';
    }
    return html + '</div>';
  }

  function docsCard(docs) {
    var body;
    if (!Array.isArray(docs)) body = note(docs && docs.error ? docs.error : 'unavailable');
    else if (!docs.length) body = '<div class="rs-note">no design docs</div>';
    else body = docs.map(function (d) {
      return '<div class="rs-doc"><span class="nm">' + esc(d.name) + '</span>' +
        (d.status_line
          ? '<span class="st" title="' + esc(d.status_line) + '">' + esc(d.status_line) + '</span>'
          : '<span class="st un">no status line</span>') + '</div>';
    }).join('');
    return '<section class="rs-card"><h3 class="rs-title">Design docs</h3>' + body + '</section>';
  }

  function questionsCard(qs) {
    var body;
    if (!Array.isArray(qs)) body = note(qs && qs.error ? qs.error : 'unavailable');
    else if (!qs.length) body = '<div class="rs-note">no open questions</div>';
    else {
      var byDoc = {};
      qs.forEach(function (q) {
        (byDoc[q.doc] = byDoc[q.doc] || []).push(q.question);
      });
      body = Object.keys(byDoc).map(function (doc) {
        return '<details><summary>' + esc(doc) +
          ' <span class="pb">(' + byDoc[doc].length + ')</span></summary><ul>' +
          byDoc[doc].map(function (q) { return '<li>' + esc(q) + '</li>'; }).join('') +
          '</ul></details>';
      }).join('');
    }
    return '<section class="rs-card rs-q"><h3 class="rs-title">Open questions</h3>' + body + '</section>';
  }

  function lessonsCard(ls) {
    var body;
    if (!ls || ls.error) body = note(ls && ls.error ? ls.error : 'unavailable');
    else body = '<div><span class="num">' + esc(ls.count) + '</span>' +
      '<span class="lbl">captured sources</span></div>' +
      (ls.recent && ls.recent.length
        ? '<ul>' + ls.recent.map(function (f) { return '<li>' + esc(f) + '</li>'; }).join('') + '</ul>'
        : '');
    return '<section class="rs-card rs-lessons"><h3 class="rs-title">Lessons</h3>' + body + '</section>';
  }

  function render() {
    if (!root || !feed) return;
    root.innerHTML =
      '<div class="rs-grid">' +
      altCard(feed.alternation) +
      boardSection(feed.lines, feed.research_lanes) +
      docsCard(feed.design_docs) +
      questionsCard(feed.open_questions) +
      lessonsCard(feed.lessons) +
      '</div>' +
      '<div class="rs-foot">feed generated ' + esc(feed.generated || '?') +
      ' · controls are advisory proposals/annotations — never governance input</div>';
    probeDocs(feed.lines);
  }

  function load() {
    return fetchJson('research.json').then(function (f) {
      feed = f;
      // skip re-render while an editor is open or the form has a draft:
      // a 60s poll must never wipe operator input mid-keystroke.
      if (canRender()) render();
    }).catch(function (e) {
      if (root) root.innerHTML = '<div class="rs-note">research feed unavailable: ' +
        esc(e.message || e) + '</div>';
    });
  }

  function canRender() {
    var draft = document.querySelector('#rs-addline input');
    return openLane === null && !(draft && draft.value);
  }

  window.ResearchView = {
    init: function (el) {
      root = el;
      if (!document.getElementById('rs-style')) {
        var st = document.createElement('style');
        st.id = 'rs-style';
        st.textContent = STYLE;
        document.head.appendChild(st);
      }
      load();
      timer = window.HnghPoll.start(load, { interval: POLL_MS });
      root.addEventListener('click', function (ev) {
        var b = ev.target.closest('button');
        if (!b) return;
        if (b.classList.contains('rs-state')) {
          stateFilter = (stateFilter === b.dataset.state) ? '' : b.dataset.state;
          if (canRender()) render();
          return;
        }
        if (b.dataset.cancel) { openLane = null; laneResult = null; render(); return; }
        if (b.classList.contains('rs-notebtn')) {
          openLane = (openLane === b.dataset.lane) ? null : b.dataset.lane;
          laneResult = null;
          render();
        }
      });
      root.addEventListener('submit', function (ev) {
        var f = ev.target.closest('form');
        if (!f) return;
        ev.preventDefault();
        if (f.id === 'rs-addline') {
          var name = f.lane.value.trim(), intent = f.intent.value.trim();
          if (!name || !intent) return;
          postJson('research-line', { name: name, intent: intent })
            .then(function () {
              addResult = { ok: true, msg: 'lane "' + name + '" proposed in the operator backlog' };
              f.reset(); load();
            })
            .catch(function (e) {
              addResult = { ok: false, msg: e.message || String(e) }; render();
            });
        } else if (f.classList.contains('rs-noteform')) {
          var lane = f.getAttribute('data-lane'), t = f.note.value.trim();
          if (!t) return;
          postJson('research-note', { lane: lane, note: t, affecting: f.affecting.checked })
            .then(function () {
              laneResult = { ok: true, msg: 'note appended' +
                (f.affecting.checked ? ' · steer alert queued' : '') };
              openLane = null; load();
            })
            .catch(function (e) {
              laneResult = { ok: false, msg: e.message || String(e) }; render();
            });
        }
      });
    },
    refresh: function () { load(); }
  };
})();
