/* sessions-view — the session observatory's full-transcript viewer, mounted
   into index.html#p-sessions > #sess-root by app.js (window.SessionsView =
   {init, refresh}; init on first tab activation, refresh() on later ones,
   plus its own 15s poll). Left: session sidebar (state chip, short id, age,
   mission; live first, then newest activity). Right: the selected session's
   conversation rendered in series from dashboard/sessions.json entries —
   user entries left-accented, assistant neutral, thinking and tool calls as
   native <details> collapsed by default (expand/collapse all in the
   toolbar), tool inputs/outputs syntax-highlighted, fenced code highlighted
   (same ~30-line regex highlighter pattern as the old sessions.js, plus a
   json language). Sessions whose feed row carries only the legacy
   record.lisp receipt tail render that instead, labeled as such. Detail
   re-renders only when the selected transcript's tail actually moved;
   auto-scroll pins to the bottom for live sessions only. All styles are
   injected here in one owned <style> tag — style.css is not touched. Keyed
   sidebar diff keeps row DOM stable across polls. Display layer only —
   never governance input. */
(function () {
  'use strict';

  var REFRESH_MS = 15000;

  /* ---- tiny shared helpers (same patterns as the legacy sessions.js) ---- */
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;',
               "'": '&#39;' }[c];
    });
  }
  function fmtAge(a) {
    if (a == null || isNaN(a)) return '—';
    if (a < 90) return Math.round(a) + 's';
    if (a < 5400) return Math.round(a / 60) + 'm';
    if (a < 129600) return (a / 3600).toFixed(1) + 'h';
    return (a / 86400).toFixed(1) + 'd';
  }
  function shortId(id) {
    id = String(id || '');
    return id.length > 22 ? '…' + id.slice(-10) : id;
  }
  function djb2(s) {
    var h = 5381;
    s = String(s || '');
    for (var i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0;
    return String(h);
  }
  function chip(state) {
    var s = String(state || 'unknown').toLowerCase();
    return '<span class="sv-chip sv-st-' + esc(s) + '">' + esc(s) + '</span>';
  }
  /* flash a copy chip green after its text lands on the clipboard */
  function copyText(text, el) {
    function flash() {
      el.classList.add('ok');
      setTimeout(function () { el.classList.remove('ok'); }, 1200);
    }
    function legacy() {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.style.cssText = 'position:fixed;opacity:0';
      document.body.appendChild(ta);
      ta.select();
      try { document.execCommand('copy'); flash(); } catch (e) { /* no */ }
      ta.remove();
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(flash, legacy);
    } else legacy();
  }
  function tsClock(ts) {
    var d = ts ? new Date(ts) : null;
    return d && !isNaN(d) ? d.toLocaleTimeString() : '';
  }

  /* ---- minimal inline highlighter: comments / strings / keywords /
     numbers / json keys. Regex-based, plain fallback. ---- */
  var LANGS = {
    lisp: { re: /(;[^\n]*)|("(?:[^"\\]|\\.)*")|(:[A-Za-z0-9_-]+)|\b(def|defun|defconstant|defparameter|setq|let|lambda|if|when|unless|cond|format|dolist|dotimes|t|nil)\b|\b(\d+(?:\.\d+)?)\b/g,
            cls: ['tok-c', 'tok-s', 'tok-k', 'tok-k', 'tok-n'] },
    python: { re: /(#[^\n]*)|('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")|\b(def|class|return|if|elif|else|for|while|import|from|as|with|try|except|finally|raise|lambda|pass|break|continue|and|or|not|in|is|None|True|False|self)\b|\b(\d+(?:\.\d+)?)\b/g,
              cls: ['tok-c', 'tok-s', 'tok-k', 'tok-n'] },
    shell: { re: /(#[^\n]*)|('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")|(\$\{?[A-Za-z_][A-Za-z0-9_]*\}?)|\b(if|then|else|elif|fi|for|while|do|done|case|esac|in|function|local|export|return|exit|set|source)\b|\b(\d+(?:\.\d+)?)\b/g,
             cls: ['tok-c', 'tok-s', 'tok-k', 'tok-k', 'tok-n'] },
    json: { re: /("(?:[^"\\]|\\.)*")(\s*:)?|\b(true|false|null)\b|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/g,
            cls: ['tok-s', 'tok-k', 'tok-k', 'tok-n'] },
    markdown: { re: /(^#{1,6}[^\n]*)|(`[^`\n]+`)|(\*\*[^*\n]+\*\*)|(\[[^\]\n]*\]\([^)\n]*\))/gm,
                cls: ['tok-k', 'tok-s', 'tok-n', 'tok-s'] }
  };
  var EXT_LANG = { lisp: 'lisp', lsp: 'lisp', cl: 'lisp', py: 'python',
                   sh: 'shell', bash: 'shell', json: 'json', jsonl: 'json',
                   md: 'markdown', markdown: 'markdown' };

  function highlight(code, langHint) {
    var lang = langHint && LANGS[langHint] ? langHint :
      EXT_LANG[(String(langHint || '').match(/\.([a-z0-9]+)$/i) || [])[1] || ''];
    var L = lang && LANGS[lang];
    if (!L) return esc(code);
    var out = '', last = 0, m;
    var re = new RegExp(L.re.source, L.re.flags); // fresh lastIndex
    while ((m = re.exec(code))) {
      out += esc(code.slice(last, m.index));
      var gi = 0;
      for (var i = 1; i < m.length; i++) if (m[i] != null) { gi = i; break; }
      out += '<span class="' + L.cls[gi - 1] + '">' + esc(m[0]) + '</span>';
      last = m.index + m[0].length;
      if (!m[0].length) re.lastIndex++; // zero-width safety
    }
    return out + esc(code.slice(last));
  }

  /* message text: highlight ```fenced blocks, escape the rest */
  function richText(text) {
    var parts = String(text || '').split(/```/);
    if (parts.length < 2) return esc(text);
    var out = '';
    for (var i = 0; i < parts.length; i++) {
      if (i % 2) { // fenced: first line may be the language
        var nl = parts[i].indexOf('\n');
        var lang = nl > 0 && parts[i].slice(0, nl).trim();
        var body = nl >= 0 ? parts[i].slice(nl + 1) : parts[i];
        out += '<pre class="sv-code"><code>' +
          highlight(body.replace(/\n$/, ''), lang || null) + '</code></pre>';
      } else if (parts[i]) {
        out += esc(parts[i]);
      }
    }
    return out;
  }

  var STYLE = [
    '.sv{display:grid;grid-template-columns:minmax(320px,38fr) 62fr;gap:12px;',
    '  grid-template-rows:minmax(0,1fr);min-height:420px;',
    '  max-height:calc(100dvh - 120px);color:var(--ink)}',
    '@media (max-width:900px){.sv{grid-template-columns:1fr;',
    '  grid-template-rows:auto;height:auto}',
    '  .sv-side{max-height:46vh}.sv-list{max-height:40vh}}',
    '.sv-side{display:flex;flex-direction:column;min-height:0;border:1px solid var(--line);',
    '  border-radius:0;background:var(--panel);overflow:hidden}',
    '.sv-side-head{padding:8px 12px;font-size:11px;letter-spacing:.08em;',
    '  text-transform:uppercase;color:var(--muted);border-bottom:1px solid var(--line);',
    '  display:flex;justify-content:space-between}',
    '.sv-list{overflow-y:auto;flex:1}',
    '.sv-row{display:flex;flex-direction:column;gap:2px;width:100%;',
    '  text-align:left;padding:5px 10px;',
    '  background:none;border:0;border-bottom:1px solid var(--line);color:var(--ink);',
    '  font:inherit;cursor:pointer}',
    '.sv-row:hover{background:rgba(128,128,128,.08)}',
    '.sv-row.sel{background:rgba(47,129,247,.14);box-shadow:inset 2px 0 0 var(--accent)}',
    '.sv-row-title{font-size:12px;font-weight:600;line-height:1.35;',
    '  overflow:hidden;text-overflow:ellipsis;white-space:nowrap;min-width:0}',
    '.sv-row-meta{display:flex;align-items:center;gap:6px;margin-top:2px;',
    '  font-size:10.5px;color:var(--muted);white-space:nowrap;min-width:0;',
    '  overflow:hidden}',
    '.sv-row-src{overflow:hidden;text-overflow:ellipsis;min-width:0}',
    '.sv-copy{flex:none;max-width:15ch;overflow:hidden;text-overflow:ellipsis;',
    '  font:10px ui-monospace,Menlo,Consolas,monospace;color:var(--dim);',
    '  border:1px solid var(--line);border-radius:2px;padding:0 5px;',
    '  line-height:15px;cursor:copy}',
    '.sv-copy:hover{color:var(--ink);border-color:var(--muted)}',
    '.sv-copy.ok{color:var(--ok);border-color:var(--ok)}',
    '.sv-chip{display:inline-block;padding:0 7px;border:1px solid var(--line);',
    '  border-radius:2px;font-size:10px;line-height:16px;flex:none}',
    '.sv-st-working,.sv-st-live{color:var(--ok);border-color:var(--ok)}',
    '.sv-st-idle{color:var(--accent);border-color:var(--accent)}',
    '.sv-st-parked{color:var(--violet,#b7a8ff);border-color:var(--violet,#b7a8ff)}',
    '.sv-st-evacuated,.sv-st-complete{color:var(--dim)}',
    '.sv-st-unknown{color:var(--muted)}',
    '.sv-main{display:flex;flex-direction:column;min-height:0;min-width:0}',
    '.sv-toolbar{display:flex;align-items:center;gap:6px;flex-wrap:wrap;',
    '  padding:6px 8px;border:1px solid var(--line);border-radius:0;',
    '  background:var(--panel)}',
    '.sv-fbtn{background:none;border:1px solid var(--line);border-radius:2px;',
    '  color:var(--muted);font-size:11px;padding:1px 9px;cursor:pointer;font:inherit}',
    '.sv-fbtn[aria-pressed="true"]{color:var(--accent);border-color:var(--accent)}',
    '.sv-q{flex:1;min-width:120px;background:var(--bg);border:1px solid var(--line);',
    '  border-radius:0;color:var(--ink);font:inherit;font-size:12px;padding:3px 8px}',
    '.sv-live-note{font-size:11px;color:var(--dim);white-space:nowrap}',
    '.sv-live-note.on{color:var(--ok)}',
    '.sv-detail{flex:1;overflow-y:auto;border:1px solid var(--line);border-top:0;',
    '  border-radius:0;background:var(--bg);padding:10px 12px 24px}',
    '.sv-head{border:1px solid var(--line);border-radius:0;background:var(--panel);',
    '  padding:8px 12px;margin-bottom:10px;font-size:12px}',
    '.sv-head-mission{font-weight:650;font-size:13px;margin-bottom:2px}',
    '.sv-head-meta{color:var(--muted);font-size:11px;display:flex;gap:10px;',
    '  flex-wrap:wrap;word-break:break-all}',
    '.sv-e{margin:0 0 8px;border:1px solid var(--line);border-radius:0;',
    '  background:var(--panel);overflow:hidden;font-size:12.5px}',
    '.sv-e-user{border-left:3px solid var(--accent)}',
    '.sv-e-assistant{border-right:3px solid var(--dim)}',
    '.sv-meta{display:flex;gap:8px;padding:4px 10px 0;color:var(--muted);',
    '  font-size:10.5px;text-transform:uppercase;letter-spacing:.06em}',
    '.sv-body{padding:4px 12px 8px;white-space:pre-wrap;word-break:break-word}',
    'details.sv-e>summary{cursor:pointer;list-style:none;display:flex;align-items:center;',
    '  gap:8px;padding:5px 10px;color:var(--muted);font-size:11.5px}',
    'details.sv-e>summary::before{content:"▸";color:var(--dim);font-size:10px}',
    'details[open].sv-e>summary::before{content:"▾"}',
    'details.sv-e>summary:hover{color:var(--ink)}',
    '.sv-think{border-style:dashed;background:transparent}',
    '.sv-think>summary{font-style:italic}',
    '.sv-think .sv-body{color:var(--muted);font-style:italic;white-space:pre-wrap}',
    '.sv-tool>summary{font-family:ui-monospace,Menlo,Consolas,monospace}',
    '.sv-tool-sum{color:var(--ink);overflow:hidden;text-overflow:ellipsis;',
    '  white-space:nowrap;flex:1}',
    '.sv-tool-name{color:var(--warn);font-weight:600;flex:none}',
    '.sv-sub{margin:4px 10px 8px;font-size:10px;letter-spacing:.08em;',
    '  text-transform:uppercase;color:var(--dim)}',
    '.sv-code{margin:4px 10px 10px;padding:8px 10px;background:var(--bg);',
    '  border:1px solid var(--line);border-radius:0;overflow-x:auto;',
    '  font:11.5px/1.5 ui-monospace,Menlo,Consolas,monospace;white-space:pre}',
    '.sv-tail{margin:4px 10px 10px;padding:8px 10px;background:var(--bg);',
    '  border:1px solid var(--line);border-radius:0;overflow-x:auto;',
    '  font:11.5px/1.5 ui-monospace,Menlo,Consolas,monospace;white-space:pre-wrap}',
    '.tok-c{color:var(--dim);font-style:italic}',
    '.tok-s{color:var(--ok)}',
    '.tok-k{color:var(--accent);font-weight:600}',
    '.tok-n{color:var(--warn)}',
    '.sv-note{color:var(--muted);font-size:12px;padding:16px;text-align:center}',
    '.sv-reason{color:var(--warn);font-size:11px;margin:4px 10px 8px}'
  ].join('\n') +
    '.sv-act{flex:none;font:10px ui-monospace,Menlo,Consolas,monospace;' +
    'color:var(--dim);border:1px solid var(--line);border-radius:2px;' +
    'padding:0 5px;line-height:15px;cursor:pointer}' +
    '.sv-act:hover{color:var(--ink);border-color:var(--muted)}' +
    '.sv-arm{color:var(--warn)}' +
    '.sv-yes,.sv-no{cursor:pointer;text-decoration:underline}' +
    '.sv-opnote{font-size:11px;white-space:nowrap;overflow:hidden;' +
    'text-overflow:ellipsis;max-width:34ch}' +
    '.sv-opnote.ok{color:var(--ok)}' +
    '.sv-opnote.err{color:var(--warn)}';

  /* ---- state ---- */
  var root = null, timer = null, data = null;
  var sel = null;            // selected session id
  var rowEls = {};           // id -> sidebar <button>
  var rowSig = {};           // id -> sidebar signature
  var detailSig = null;      // selected transcript signature
  var filterRole = 'all';
  var query = '';
  var pin = {};              // session id -> pinned to bottom (live only)
  var restoringScroll = false;
  var sliceFails = 0;        // >=2: whole-feed fallback until the next refresh()
  var armedTail = null;      // session whose spawn is armed, awaiting confirm
  var armedTile = false;     // toolbar tile confirm
  var armedFlag = null;      // session whose flag is armed, awaiting confirm

  function $(cls, el) { return (el || root).querySelector(cls); }
  function $all(cls, el) {
    return Array.prototype.slice.call((el || root).querySelectorAll(cls));
  }

  function sessionSig(r) {
    var d = (r && r.detail) || {};
    var es = d.entries || [];
    var last = es[es.length - 1] || {};
    return [r.state, d.counts && d.counts.shown, es.length,
            last.ts, last.text && last.text.length, d.reason].join('|');
  }

  /* live sessions first, then most-recently-active first */
  function sortKey(r) {
    var live = /^(live|working)$/i.test(String(r.state || '')) ? 0 : 1;
    var act = r.last_active_age != null ? r.last_active_age :
              (r.age != null ? r.age : 1e9);
    return live * 1e13 + act;
  }

  /* ---- sidebar ---- */
  function rowHtml(r) {
    var act = r.last_active_age != null ? r.last_active_age : r.age;
    var title = r.title || r.mission || r.source || shortId(r.id);
    var full = r.title_full || r.mission || title;
    return '<span class="sv-row-title" title="' + esc(full) + '">' +
      esc(title) + '</span>' +
      '<span class="sv-row-meta">' + chip(r.state) +
      '<span>' + esc(fmtAge(act)) + '</span>' +
      '<span class="sv-row-src" title="' + esc(r.source || '') + '">' +
      esc(r.source || '') + '</span>' +
      '<span class="sv-copy" data-full="' + esc(r.id) +
      '" title="copy ' + esc(r.id) + ' — run-&lt;UTC timestamp&gt;-&lt;pid&gt; of the wake that spawned it">' +
      esc(shortId(r.id)) + '</span>' +
      tailCtl(r.id) +
      flagCtl(r.id) +
      '</span>';
  }

  /* per-session spawn control (B4): names a launcher key only — the server
     owns the command template. Arm/confirm inline, same pattern as the
     operator-item dismiss. */
  function tailCtl(id) {
    if (armedTail === id)
      return '<span class="sv-act sv-arm" data-tail-arm="' + esc(id) + '">tail? ' +
        '<span class="sv-yes" data-tail-yes="' + esc(id) + '">yes</span>/' +
        '<span class="sv-no" data-tail-no="' + esc(id) + '">no</span></span>';
    return '<span class="sv-act" data-tail="' + esc(id) +
      '" title="spawn a desktop terminal tailing this transcript (launcher: konsole-tail)">tail</span>';
  }

  /* per-session operator flag (step 5): appends one operator-flag line to
     agent-handoffs.md via the token-guarded /flag. Arm/confirm inline like
     the tail control; the server requires a non-empty <=200-char note, and
     the row is a <button> (no inputs inside), so the note is a native
     prompt prefilled from the session's title/mission. */
  function flagCtl(id) {
    if (armedFlag === id)
      return '<span class="sv-act sv-arm" data-flag-arm="' + esc(id) + '">flag? ' +
        '<span class="sv-yes" data-flag-yes="' + esc(id) + '">yes</span>/' +
        '<span class="sv-no" data-flag-no="' + esc(id) + '">no</span></span>';
    return '<span class="sv-act" data-flag="' + esc(id) +
      '" title="append an operator-flag line for this session to agent-handoffs.md">flag</span>';
  }

  function renderSidebar() {
    var list = $('.sv-list');
    var rows = (data && data.sessions) || [];
    rows.sort(function (a, b) { return sortKey(a) - sortKey(b); });
    var seen = {};
    rows.forEach(function (r, i) {
      seen[r.id] = true;
      var el = rowEls[r.id];
      var sig = sessionSig(r) + '|' + (r.title || '') + '|' + (r.mission || '') +
        '|' + (r.age || '') + '|' + (armedTail === r.id ? 'arm' : '') +
        '|' + (armedFlag === r.id ? 'arm' : '');
      if (!el) {
        el = document.createElement('button');
        el.className = 'sv-row';
        el.dataset.id = r.id;
        el.addEventListener('click', function (ev) {
          // the id chip copies and the tail chip spawns; neither selects
          if (ev.target.closest && ev.target.closest('.sv-copy, .sv-act')) return;
          select(r.id);
        });
        el.innerHTML = rowHtml(r);
        rowEls[r.id] = el;
        rowSig[r.id] = sig;
      } else if (rowSig[r.id] !== sig) {
        el.innerHTML = rowSig[r.id] = sig, el.innerHTML = rowHtml(r);
      }
      el.classList.toggle('sel', r.id === sel);
      if (list.children[i] !== el) list.insertBefore(el, list.children[i] || null);
    });
    Object.keys(rowEls).forEach(function (id) {
      if (!seen[id]) { rowEls[id].remove(); delete rowEls[id]; delete rowSig[id]; }
    });
    $('.sv-count').textContent = String(rows.length);
    if (!sel || !seen[sel]) select(rows.length ? rows[0].id : null);
  }

  /* ---- detail ---- */
  function oneLine(text) {
    var t = String(text || '').replace(/\s+/g, ' ').trim();
    return t.length > 90 ? t.slice(0, 90) + '…' : t;
  }

  function entryHtml(e, out) {
    var clock = esc(tsClock(e.ts));
    // collapsed by default; auto-open only under an active filter/search
    var constrained = filterRole !== 'all' || query;
    var open = constrained && match(e) ? ' open' : '';
    if (e.kind === 'thinking') {
      return '<details class="sv-e sv-think"' + open +
        '><summary>thinking · ' + esc(String(e.text.length)) +
        ' chars</summary>' +
        '<div class="sv-body">' + esc(e.text) + '</div></details>';
    }
    if (e.kind === 'tool_call') {
      return '<details class="sv-e sv-tool"' + open + '><summary>' +
        '<span class="sv-tool-name">⚒ ' + esc(e.tool || 'tool') + '</span>' +
        '<span class="sv-tool-sum">' + esc(oneLine(e.text)) + '</span>' +
        '<span>' + clock + '</span></summary>' +
        '<div class="sv-sub">input</div>' +
        '<pre class="sv-code"><code>' + highlight(e.text, 'json') +
        '</code></pre>' +
        (out ? '<div class="sv-sub">output' +
          (out.truncated ? ' (truncated)' : '') + '</div>' +
          '<pre class="sv-code"><code>' + highlight(out.text, null) +
          '</code></pre>' : '') + '</details>';
    }
    if (e.kind === 'tool_result') {
      return '<details class="sv-e sv-tool"' + open + '><summary>' +
        '<span class="sv-tool-name">↳ ' + esc(e.tool || 'result') + '</span>' +
        '<span class="sv-tool-sum">' + esc(oneLine(e.text)) + '</span>' +
        '<span>' + clock + '</span></summary>' +
        '<pre class="sv-code"><code>' + highlight(e.text, null) +
        '</code></pre></details>';
    }
    var cls = e.role === 'user' ? 'sv-e-user' : 'sv-e-assistant';
    return '<div class="sv-e ' + cls + '"><div class="sv-meta">' +
      esc(e.role) + (e.kind === 'code' ? ' · code' : '') +
      '<span style="margin-left:auto">' + clock + '</span></div>' +
      '<div class="sv-body">' +
      (e.kind === 'code' ? '<pre class="sv-code"><code>' +
        highlight(e.text, null) + '</code></pre>' : richText(e.text)) +
      '</div></div>';
  }

  function match(e) {
    if (filterRole !== 'all' && e.role !== filterRole) return false;
    if (query &&
        String(e.text || '').toLowerCase().indexOf(query) < 0) return false;
    return true;
  }

  function renderDetail() {
    var box = $('.sv-detail');
    var r = data && data.sessions.filter(function (x) {
      return x.id === sel;
    })[0];
    if (!r) { box.innerHTML = '<div class="sv-note">no session selected</div>'; return; }
    var d = r.detail || {};
    var note = $('.sv-live-note');
    if (note) {
      var live = /^(live|working)$/i.test(String(r.state || ''));
      note.textContent = live ? '● live — following tail' : 'static transcript';
      note.className = 'sv-live-note' + (live ? ' on' : '');
    }
    var es = d.entries || [];
    var sig = sessionSig(r) + '|' + filterRole + '|' + query;
    if (sig === detailSig) { maybePin(); return; }
    detailSig = sig;

    // pair tool_results to their calls; leftovers render standalone
    var byCall = {}, out = [], i, e;
    es.forEach(function (x) {
      if (x.kind === 'tool_result' && x.call_id) byCall[x.call_id] = x;
    });
    var used = {};
    es.forEach(function (x) {
      if (x.kind === 'tool_call' && x.call_id && byCall[x.call_id]) {
        used[x.call_id] = true;
        out.push([x, byCall[x.call_id]]);
      } else if (x.kind === 'tool_result' && x.call_id && used[x.call_id]) {
        /* consumed by its call */
      } else {
        out.push([x, null]);
      }
    });

    var html = '<div class="sv-head"><div class="sv-head-mission">' +
      esc(r.title || r.mission || '(no title)') + '</div><div class="sv-head-meta">' +
      chip(r.state) +
      '<span class="sv-copy" data-full="' + esc(r.id) + '" title="copy ' +
      esc(r.id) + ' — run-&lt;UTC timestamp&gt;-&lt;pid&gt; of the wake that spawned it">' +
      esc(shortId(r.id)) + '</span>' +
      '<span>' + esc(r.source || '') + '</span><span>activity ' +
      esc(fmtAge(r.last_active_age != null ? r.last_active_age : r.age)) +
      ' ago</span><span title="' + esc(d.transcript || '') + '">' +
      esc((d.counts && d.counts.shown) || 0) + ' entries' +
      ((d.counts && d.counts.total > d.counts.shown) ?
        ' (of ' + d.counts.total + ')' : '') + '</span></div>' +
      (d.reason ? '<div class="sv-reason">' + esc(d.reason) + '</div>' : '') +
      '</div>';

    if (!es.length && d.tail) {
      html += '<div class="sv-e"><div class="sv-meta">receipt tail (record.lisp)' +
        (d.truncated ? ' · truncated' : '') +
        '</div><pre class="sv-tail"><code>' + highlight(d.tail, 'x.lisp') +
        '</code></pre></div>';
    } else if (!es.length) {
      html += '<div class="sv-note">no entries parsed</div>';
    }
    for (i = 0; i < out.length; i++) {
      e = out[i][0];
      var o = out[i][1];
      if (!match(e) && !(o && match(o))) continue; // search tool output too
      html += entryHtml(e, out[i][1]);
    }
    var wasBottom = box.scrollHeight - box.scrollTop -
      box.clientHeight < 60;
    var scrollPos = box.scrollTop;
    box.innerHTML = html;
    if (!/^(live|working)$/i.test(String(r.state || ''))) {
      box.scrollTop = Math.min(scrollPos, box.scrollHeight); // keep position
    } else {
      maybePin(wasBottom);
    }
  }

  function maybePin(wasBottom) {
    var box = $('.sv-detail');
    var r = data && data.sessions.filter(function (x) { return x.id === sel; })[0];
    if (!box || !r) return;
    var live = /^(live|working)$/i.test(String(r.state || ''));
    if (live && (pin[sel] !== false) && (wasBottom !== false)) {
      box.scrollTop = box.scrollHeight;
    }
  }

  function select(id) {
    sel = id;
    detailSig = null; // force render
    renderSidebarSel();
    renderDetail();
    // switch = immediate slice fetch for the newly selected transcript
    if (data && sel) fetchSlice(function (ok) {
      if (ok) { renderSidebar(); renderDetail(); }
    });
  }
  function renderSidebarSel() {
    Object.keys(rowEls).forEach(function (id) {
      rowEls[id].classList.toggle('sel', id === sel);
    });
  }

  /* ---- fetch + wiring ---- */
  /* B5 slice discipline: the sidebar rail keeps the whole sessions.json
     (row metadata only once loaded); the ongoing 15s poll fetches
     /session/<id>?tail=20 for the SELECTED session only — kilobytes
     instead of the megabyte feed. Two slice failures fall back to the
     old whole-feed poll until the next manual refresh. */
  function fetchFeed(cb) {
    var t = setTimeout(function () { cb(false, null); }, 8000);
    window.fetch('sessions.json', { cache: 'no-store' })
      .then(function (res) { return res.ok ? res.json() : null; })
      .then(function (j) { clearTimeout(t); cb(!!j, j); })
      .catch(function () { clearTimeout(t); cb(false, null); });
  }
  function applyWhole(ok, d2) {
    if (!ok) return;
    data = d2;
    renderSidebar();
    renderDetail();
  }
  function fetchSlice(cb) {
    var t = setTimeout(function () { cb(false); }, 8000);
    window.fetch('/session/' + encodeURIComponent(sel) + '?tail=20', { cache: 'no-store' })
      .then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then(function (j) {
        clearTimeout(t);
        var r = data && data.sessions.filter(function (x) { return x.id === sel; })[0];
        if (!j || !j.entries || !r) { cb(false); return; }
        r.detail = {
          entries: j.entries,
          counts: (r.detail && r.detail.counts) ||
            { shown: j.entries.length, total: j.entries.length },
          reason: r.detail && r.detail.reason,
          tail: r.detail && r.detail.tail
        };
        cb(true);
      })
      .catch(function () { clearTimeout(t); cb(false); });
  }
  function fetch() {
    if (!data || !sel) { fetchFeed(applyWhole); return; }
    if (sliceFails >= 2) { fetchFeed(applyWhole); return; } // poll fallback
    fetchSlice(function (ok) {
      if (ok) {
        sliceFails = 0;
        renderSidebar();
        renderDetail();
        return;
      }
      sliceFails++;
      fetchFeed(applyWhole); // degraded: the old whole-feed path
    });
  }
  /* spawn/tile ops (B4): the client only NAMES a launcher key / profile —
     the server owns the command template and validates everything. The
     tile 403 (tiling disabled) surfaces verbatim, never silently. */
  function opNote(ok, msg) {
    var el = $('.sv-opnote');
    if (!el) return;
    el.textContent = msg;
    el.className = 'sv-opnote' + (ok ? ' ok' : ' err');
  }
  function doTail(id) {
    window.HnghOps.post('/spawn', { session: id, launcher: 'konsole-tail' })
      .then(function () { armedTail = null; renderSidebar(); opNote(true, 'spawned konsole-tail for ' + shortId(id)); })
      .catch(function (e) { armedTail = null; renderSidebar(); opNote(false, e.message || String(e)); });
  }
  function doTile() {
    var r = data && data.sessions.filter(function (x) { return x.id === sel; })[0];
    if (!r) { opNote(false, 'no session selected'); return; }
    window.HnghOps.post('/tile', { profile: 'duo', sessions: [r.id] })
      .then(function (j) {
        armedTile = false;
        var b = $('[data-tile]');
        if (b) { b.setAttribute('aria-pressed', 'false'); b.textContent = 'tile'; }
        opNote(true, 'tiled ' + shortId(r.id) +
          ((j.skipped && j.skipped.length) ? ' (skipped: no transcript)' : ''));
      })
      .catch(function (e) {
        armedTile = false;
        var b = $('[data-tile]');
        if (b) { b.setAttribute('aria-pressed', 'false'); b.textContent = 'tile'; }
        opNote(false, e.message || String(e)); // 403: tiling disabled, verbatim
      });
  }
  function doFlag(id) {
    var rows = (data && data.sessions) || [];
    var r = rows.filter(function (x) { return x.id === id; })[0];
    var def = String((r && (r.title || r.mission)) || 'needs attention')
      .replace(/\|/g, '').slice(0, 200);
    var note = window.prompt('flag ' + shortId(id) + ' — note:', def);
    armedFlag = null;
    renderSidebar();
    if (note == null) return; // operator cancelled the prompt
    note = note.trim().replace(/\|/g, '');
    if (!note) { opNote(false, 'flag needs a note'); return; }
    window.HnghOps.post('/flag', { session: id, note: note })
      .then(function () { opNote(true, 'flagged ' + shortId(id)); })
      .catch(function (e) { opNote(false, e.message || String(e)); });
  }
  function init(el) {
    if (root) return; // idempotent
    root = el;
    var style = document.createElement('style');
    style.id = 'hngh-sessions-style';
    style.textContent = STYLE;
    document.head.appendChild(style);
    root.innerHTML =
      '<div class="sv">' +
      '<aside class="sv-side"><div class="sv-side-head">sessions' +
      '<span class="sv-count">0</span></div><div class="sv-list"></div></aside>' +
      '<section class="sv-main"><div class="sv-toolbar">' +
      ['all', 'user', 'assistant', 'thinking', 'tool'].map(function (r0) {
        return '<button class="sv-fbtn" data-role="' + r0 + '" aria-pressed="' +
          (r0 === 'all') + '">' + r0 + '</button>';
      }).join('') +
      '<input class="sv-q" type="search" placeholder="filter entries…" ' +
      'aria-label="filter entries">' +
      '<button class="sv-fbtn" data-tile aria-pressed="false" ' +
      'title="tile the selected transcript into a desktop terminal window (profile: duo)">tile</button>' +
      '<button class="sv-fbtn sv-x" data-x="open">expand all</button>' +
      '<button class="sv-fbtn sv-x" data-x="close">collapse all</button>' +
      '<span class="sv-opnote" role="status"></span>' +
      '<span class="sv-live-note"></span></div>' +
      '<div class="sv-detail" tabindex="0"><div class="sv-note">loading…</div></div>' +
      '</section></div>';

    $all('.sv-fbtn[data-role]').forEach(function (b) {
      b.addEventListener('click', function () {
        filterRole = b.dataset.role;
        $all('.sv-fbtn[data-role]').forEach(function (x) {
          x.setAttribute('aria-pressed', String(x === b));
        });
        detailSig = null;
        renderDetail();
      });
    });
    // F9: the filter re-renders the whole transcript per keystroke —
    // debounce 300ms so fast typing does not re-highlight 194 entries
    // per character.
    var qTimer = null;
    $('.sv-q').addEventListener('input', function (ev) {
      var v = ev.target.value;
      clearTimeout(qTimer);
      qTimer = setTimeout(function () {
        query = v.trim().toLowerCase();
        detailSig = null;
        renderDetail();
      }, 300);
    });
    $all('.sv-x').forEach(function (b) {
      b.addEventListener('click', function () {
        var open = b.dataset.x === 'open';
        $all('details.sv-e', $('.sv-detail')).forEach(function (d0) {
          d0.open = open;
        });
      });
    });
    var box = $('.sv-detail');
    box.addEventListener('scroll', function () {
      if (restoringScroll) return;
      var dist = box.scrollHeight - box.scrollTop - box.clientHeight;
      pin[sel] = dist <= 60;
    });
    root.addEventListener('click', function (ev) {
      var t = ev.target.closest ? ev.target.closest('.sv-copy') : null;
      if (t) copyText(t.dataset.full || t.textContent, t);
      var a;
      if ((a = ev.target.closest ? ev.target.closest('[data-tail]') : null)) {
        armedTail = a.getAttribute('data-tail'); // arm: confirm inline
        renderSidebar();
      } else if ((a = ev.target.closest ? ev.target.closest('[data-tail-no]') : null)) {
        armedTail = null;
        renderSidebar();
      } else if ((a = ev.target.closest ? ev.target.closest('[data-tail-yes]') : null)) {
        doTail(a.getAttribute('data-tail-yes'));
      } else if ((a = ev.target.closest ? ev.target.closest('[data-flag]') : null)) {
        armedFlag = a.getAttribute('data-flag'); // arm: confirm inline
        renderSidebar();
      } else if ((a = ev.target.closest ? ev.target.closest('[data-flag-no]') : null)) {
        armedFlag = null;
        renderSidebar();
      } else if ((a = ev.target.closest ? ev.target.closest('[data-flag-yes]') : null)) {
        doFlag(a.getAttribute('data-flag-yes'));
      } else if ((a = ev.target.closest ? ev.target.closest('[data-tile]') : null)) {
        if (armedTile) doTile();
        else {
          armedTile = true; // arm: second click confirms
          a.setAttribute('aria-pressed', 'true');
          a.textContent = 'tile ' + shortId(sel) + '? confirm';
        }
      }
    });

    timer = window.HnghPoll.start(fetch, { interval: REFRESH_MS });
  }

  function refresh() {
    sliceFails = 0;
    fetchFeed(applyWhole); // manual refresh also re-reads the rail metadata
  }

  window.SessionsView = { init: init, refresh: refresh };
})();
