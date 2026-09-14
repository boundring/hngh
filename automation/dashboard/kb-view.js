/* kb-view — the Knowledge Base tab, mounted into index.html#p-kb >
   #kb-root by app.js (window.KBView = {init, refresh}; lazy init on first
   tab activation, refresh() on later ones — no poll timer: the vault
   changes rarely and dashboard/kb/ is re-snapshotted by the
   refresh-dashboard.sh cadence via jobs/kb-feed.py).

   Left pane: search box + doc list (title, size, date) over
   kb/index.json. Search matches title + preview always, and the full
   text of every doc opened this session (client-side cache). Multiple
   space-separated tokens must all match. A ?q=<token> URL param
   pre-filters the list (deep-link target for the Research view).

   Right pane: reader. The markdown is rendered as formatted text by a
   minimal md-to-html converter (headings/bold/italic/code/lists/quotes/
   hr; same regex-esc-first discipline as the sessions-view highlighter).
   Links are rendered as non-clickable cited text — nothing in the KB
   navigates the operator away. Full-text search within the open doc:
   matches are wrapped in <mark> over text nodes only (tag-safe), Enter
   cycles through them.

   Display layer only — never governance input. All styles live in one
   owned <style> tag (kb- prefix); style.css is not touched. */
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
      .then(function (r) { clearTimeout(t); if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
      .catch(function (e) { clearTimeout(t); throw e; });
  }
  function fetchJson(url, ms) {
    return fetchText(url, ms).then(function (t) { return JSON.parse(t); });
  }
  function kb(n) {
    return n < 1024 ? n + ' B' : (n / 1024).toFixed(1) + ' KB';
  }
  function ago(ts) {
    var t = Date.parse(ts);
    if (isNaN(t)) return '';
    var s = (Date.now() - t) / 1000;
    if (s < 0) s = 0;
    if (s < 5400) return Math.round(s / 60) + 'm ago';
    if (s < 172800) return (Math.round(s / 3600 * 10) / 10) + 'h ago';
    return Math.round(s / 86400) + 'd ago';
  }

  /* ---- minimal markdown -> html (esc first, then inline spans) ---- */
  function inline(s) {
    var out = esc(s);
    out = out.replace(/`([^`\n]+)`/g, function (_, c) { return '<code>' + c + '</code>'; });
    out = out.replace(/\*\*([^*\n]+)\*\*/g, '<b>$1</b>');
    out = out.replace(/(^|[\s(])\*([^*\n]+)\*(?=[\s).,;:!?]|$)/g, '$1<i>$2</i>');
    // links as cited text: [text](url) -> text <cite>(url)</cite> (also ![..])
    out = out.replace(/!?\[([^\]\n]*)\]\(([^)\n]*)\)/g,
      function (_, txt, url) {
        return txt + (url ? ' <cite class="kb-cite">(' + url + ')</cite>' : '');
      });
    return out;
  }
  function mdToHtml(text) {
    var lines = String(text || '').split('\n');
    var out = [], i = 0, para = [];
    function flushPara() {
      if (para.length) { out.push('<p>' + inline(para.join(' ')) + '</p>'); para = []; }
    }
    while (i < lines.length) {
      var l = lines[i];
      var fence = l.match(/^\s*```\s*(\S*)\s*$/);
      if (fence) { // fenced code: language line dropped, body verbatim
        flushPara();
        var body = [];
        i++;
        while (i < lines.length && !/^\s*```/.test(lines[i])) { body.push(lines[i]); i++; }
        i++; // closing fence
        out.push('<pre class="kb-code"><code>' + esc(body.join('\n')) + '</code></pre>');
        continue;
      }
      var h = l.match(/^(#{1,6})\s+(.*)$/);
      if (h) { flushPara(); out.push('<h' + h[1].length + '>' + inline(h[2]) + '</h' + h[1].length + '>'); i++; continue; }
      if (/^\s*(?:---+|\*\*\*+)\s*$/.test(l)) { flushPara(); out.push('<hr>'); i++; continue; }
      if (/^\s*>/.test(l)) {
        flushPara();
        var q = [];
        while (i < lines.length && /^\s*>/.test(lines[i])) {
          q.push(lines[i].replace(/^\s*>\s?/, '')); i++;
        }
        out.push('<blockquote>' + inline(q.join(' ')) + '</blockquote>');
        continue;
      }
      var li = l.match(/^\s*(?:[-*+]|\d+[.)])\s+(.*)$/);
      if (li) {
        flushPara();
        var ord = /^\s*\d/.test(l), items = [];
        while (i < lines.length) {
          var m = lines[i].match(/^\s*(?:[-*+]|\d+[.)])\s+(.*)$/);
          if (m) { items.push(m[1]); i++; continue; }
          // indented continuation folds into the previous item
          if (items.length && /^\s+\S/.test(lines[i])) { items[items.length - 1] += ' ' + lines[i].trim(); i++; continue; }
          break;
        }
        out.push(ord ? '<ol><li>' + items.map(inline).join('</li><li>') + '</li></ol>'
                     : '<ul><li>' + items.map(inline).join('</li><li>') + '</li></ul>');
        continue;
      }
      if (/^\s*$/.test(l)) { flushPara(); i++; continue; }
      para.push(l.trim()); i++;
    }
    flushPara();
    return out.join('\n');
  }

  /* ---- in-doc search: wrap matches in <mark> over text nodes ---- */
  function markMatches(container, term) {
    var marks = [];
    if (!term) return marks;
    var lower = term.toLowerCase();
    var walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT, null);
    var nodes = [], n;
    while ((n = walker.nextNode())) nodes.push(n);
    nodes.forEach(function (node) {
      var txt = node.nodeValue;
      var idx = txt.toLowerCase().indexOf(lower);
      if (idx < 0) return;
      var frag = document.createDocumentFragment(), rest = txt, pos = 0;
      while ((idx = rest.toLowerCase().indexOf(lower)) >= 0) {
        frag.appendChild(document.createTextNode(rest.slice(0, idx)));
        var mk = document.createElement('mark');
        mk.className = 'kb-mk';
        mk.textContent = rest.slice(idx, idx + term.length);
        frag.appendChild(mk);
        marks.push(mk);
        rest = rest.slice(idx + term.length);
      }
      frag.appendChild(document.createTextNode(rest));
      node.parentNode.replaceChild(frag, node);
    });
    return marks;
  }

  /* ---- owned styles (kb- prefix) ---- */
  var STYLE = [
    '.kb{display:grid;grid-template-columns:minmax(280px,30fr) 70fr;gap:12px;',
    '  min-height:420px;max-height:calc(100dvh - 120px);color:var(--ink)}',
    '.kb-list{background:var(--panel);border:1px solid var(--line);border-radius:0;',
    '  padding:8px;display:flex;flex-direction:column;min-height:0;min-width:0}',
    '.kb-search{background:var(--bg);border:1px solid var(--line);border-radius:0;',
    '  color:var(--ink);padding:4px 8px;font-size:12.5px;width:100%;box-sizing:border-box}',
    '.kb-count{color:var(--dim);font-size:11px;margin:5px 0 3px}',
    '.kb-rows{overflow-y:auto;min-height:0}',
    '.kb-row{padding:4px 6px;border-top:1px solid var(--line);cursor:pointer;',
    '  border-radius:0;min-width:0}',
    '.kb-row:first-child{border-top:0}',
    '.kb-row:hover{background:var(--bg)}',
    '.kb-row.on{background:var(--bg);box-shadow:inset 2px 0 0 var(--accent)}',
    '.kb-row .t{font-size:12.5px;font-weight:500;overflow:hidden;text-overflow:ellipsis;',
    '  white-space:nowrap}',
    '.kb-row .m{color:var(--dim);font-size:11px;display:flex;gap:8px}',
    '.kb-row .pv{color:var(--muted);font-size:11.5px;margin-top:1px;overflow:hidden;',
    '  text-overflow:ellipsis;white-space:nowrap}',
    '.kb-reader{background:var(--panel);border:1px solid var(--line);border-radius:0;',
    '  padding:10px 14px;overflow-y:auto;min-height:0;min-width:0}',
    '.kb-rhead{display:flex;gap:10px;align-items:baseline;flex-wrap:wrap;',
    '  border-bottom:1px solid var(--line);padding-bottom:6px;margin-bottom:8px}',
    '.kb-rhead .t{font-size:15px;font-weight:600}',
    '.kb-rhead .m{color:var(--dim);font-size:11.5px}',
    '.kb-find{margin-left:auto;display:flex;gap:5px;align-items:center}',
    '.kb-find input{background:var(--bg);border:1px solid var(--line);border-radius:0;',
    '  color:var(--ink);padding:2px 7px;font-size:12px;width:150px}',
    '.kb-find .n{color:var(--dim);font-size:11px;min-width:44px;text-align:right}',
    '.kb-btn{background:var(--bg);border:1px solid var(--line);border-radius:0;',
    '  color:var(--ink);padding:2px 8px;font-size:11.5px;cursor:pointer}',
    '.kb-btn:hover{border-color:var(--accent)}',
    '.kb-doc{font-size:13.5px;line-height:1.55;max-width:78ch}',
    '.kb-doc h1,.kb-doc h2,.kb-doc h3,.kb-doc h4,.kb-doc h5,.kb-doc h6{',
    '  margin:.9em 0 .35em;line-height:1.25}',
    '.kb-doc h1{font-size:19px}.kb-doc h2{font-size:16px}.kb-doc h3{font-size:14px}',
    '.kb-doc h4,.kb-doc h5,.kb-doc h6{font-size:13px}',
    '.kb-doc p{margin:.45em 0}',
    '.kb-doc ul,.kb-doc ol{margin:.4em 0;padding-left:1.4em}',
    '.kb-doc li{margin:.18em 0}',
    '.kb-doc blockquote{border-left:3px solid var(--line);margin:.5em 0;padding:2px 10px;',
    '  color:var(--muted)}',
    '.kb-doc hr{border:0;border-top:1px solid var(--line);margin:.9em 0}',
    '.kb-doc code{background:var(--bg);border:1px solid var(--line);border-radius:0;',
    '  padding:0 4px;font-size:12px}',
    '.kb-doc pre.kb-code{background:var(--bg);border:1px solid var(--line);border-radius:0;',
    '  padding:8px 10px;overflow-x:auto;margin:.5em 0}',
    '.kb-doc pre.kb-code code{border:0;background:none;padding:0;font-size:12px}',
    '.kb-doc .kb-cite{color:var(--dim);font-size:11px;font-style:normal}',
    'mark.kb-mk{background:var(--accent);color:var(--bg);border-radius:0;padding:0 1px}',
    '.kb-note{color:var(--warn);font-size:12px}',
    '.kb-empty{color:var(--muted);font-size:12.5px;padding:8px 4px}',
    '.kb-foot{grid-column:1/-1;color:var(--dim);font-size:11px}',
    '@media (max-width:900px){.kb{grid-template-columns:1fr;height:auto}',
    '  .kb-rows{max-height:300px}}'
  ].join('\n');

  /* ---- state ---- */
  var root = null, index = null, query = '', openSlug = null;
  var texts = {};      // slug -> full text (loaded this session)
  var marks = [], markPos = -1;

  function tokens(q) {
    return String(q || '').toLowerCase().split(/\s+/).filter(Boolean);
  }
  function matches(d) {
    var tks = tokens(query);
    if (!tks.length) return true;
    var hay = (d.title + ' ' + d.slug + ' ' + (d.preview || '')).toLowerCase() +
      (texts[d.slug] || '').toLowerCase();
    return tks.every(function (t) { return hay.indexOf(t) >= 0; });
  }

  function listRows() {
    var docs = (index && Array.isArray(index.docs)) ? index.docs : [];
    var shown = docs.filter(matches);
    var head = '<input class="kb-search" id="kb-q" type="text" placeholder="search the knowledge base…" ' +
      'value="' + esc(query) + '">';
    if (!docs.length) return head + '<div class="kb-empty">kb/index.json has no docs — run jobs/kb-feed.py</div>';
    var rows = shown.map(function (d) {
      return '<div class="kb-row' + (d.slug === openSlug ? ' on' : '') + '" data-slug="' + esc(d.slug) + '">' +
        '<div class="t" title="' + esc(d.title) + '">' + esc(d.title) + '</div>' +
        '<div class="m"><span>' + kb(d.size) + '</span><span>' + esc(ago(d.mtime)) + '</span></div>' +
        '<div class="pv" title="' + esc(d.preview || '') + '">' + esc(d.preview || '') + '</div>' +
        '</div>';
    }).join('');
    return head +
      '<div class="kb-count">' + shown.length + ' of ' + docs.length + ' docs' +
      (query ? ' · filter: ' + esc(query) : '') + '</div>' +
      '<div class="kb-rows">' + (rows || '<div class="kb-empty">no docs match</div>') + '</div>';
  }

  function readerHtml() {
    if (!openSlug) {
      return '<div class="kb-empty" style="padding:14px">select a document on the left</div>';
    }
    var d = index.docs.filter(function (x) { return x.slug === openSlug; })[0] || { title: openSlug };
    var text = texts[openSlug];
    if (text == null) {
      return '<div class="kb-note">loading ' + esc(openSlug) + '…</div>';
    }
    return '<div class="kb-rhead"><span class="t">' + esc(d.title) + '</span>' +
      '<span class="m">' + kb(d.size || 0) + ' · ' + esc(d.mtime || '') + '</span>' +
      '<span class="kb-find"><input id="kb-find" type="text" placeholder="find in document">' +
      '<span class="n" id="kb-marks"></span><button class="kb-btn" id="kb-next" type="button">next</button></span>' +
      '</div>' +
      '<div class="kb-doc" id="kb-doc">' + mdToHtml(text) + '</div>';
  }

  function renderList(focusInput) {
    var list = root.querySelector('.kb-list');
    if (!list) return;
    list.innerHTML = listRows();
    var input = list.querySelector('#kb-q');
    if (input) {
      input.addEventListener('input', function () {
        query = input.value;
        var rows = root.querySelector('.kb-rows'), cnt = root.querySelector('.kb-count');
        var fresh = document.createElement('div');
        fresh.innerHTML = listRows();
        var newRows = fresh.querySelector('.kb-rows'), newCnt = fresh.querySelector('.kb-count');
        // re-render rows only — never the input the operator is typing in
        if (rows && newRows) rows.replaceWith(newRows);
        if (cnt && newCnt) cnt.replaceWith(newCnt);
        wireRows();
      });
    }
    wireRows();
  }

  function wireRows() {
    var rows = root.querySelector('.kb-rows');
    if (!rows) return;
    rows.onclick = function (ev) {
      var r = ev.target.closest('.kb-row');
      if (r) open(r.getAttribute('data-slug'));
    };
  }

  function renderReader() {
    var pane = root.querySelector('.kb-reader');
    if (!pane) return;
    pane.innerHTML = readerHtml();
    marks = []; markPos = -1;
    var find = pane.querySelector('#kb-find');
    if (find) {
      var counter = pane.querySelector('#kb-marks');
      var run = function () {
        var doc = pane.querySelector('#kb-doc');
        if (doc) {
          var term = find.value;
          // re-render the doc body to clear previous marks, then re-mark
          doc.innerHTML = mdToHtml(texts[openSlug] || '');
          marks = markMatches(doc, term);
          markPos = -1;
          counter.textContent = marks.length ? '0/' + marks.length : '';
        }
      };
      var next = function () {
        if (!marks.length) return;
        markPos = (markPos + 1) % marks.length;
        marks.forEach(function (m, i) { m.classList.toggle('cur', i === markPos); });
        marks[markPos].scrollIntoView({ block: 'center' });
        counter.textContent = (markPos + 1) + '/' + marks.length;
      };
      find.addEventListener('input', run);
      find.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); next(); } });
      pane.querySelector('#kb-next').addEventListener('click', next);
    }
  }

  function render() {
    if (!root || !index) return;
    var sum = document.getElementById('kb-sum');
    if (sum) {
      var n = Array.isArray(index.docs) ? index.docs.length : 0;
      sum.textContent = n + ' docs · snapshot @ ' + ago(index.generated);
    }
    if (!root.querySelector('.kb-list')) {
      root.innerHTML =
        '<div class="kb">' +
        '<div class="kb-list"></div>' +
        '<div class="kb-reader"></div>' +
        '<div class="kb-foot">knowledge base snapshot of ~/.llm-wiki/wiki/sources · ' +
        esc(index.generated || '') + ' · re-snapshotted by jobs/kb-feed.py (refresh-dashboard cadence)</div>' +
        '</div>';
    } else {
      root.querySelector('.kb-foot').textContent =
        'knowledge base snapshot of ~/.llm-wiki/wiki/sources · ' +
        (index.generated || '') + ' · re-snapshotted by jobs/kb-feed.py (refresh-dashboard cadence)';
    }
    renderList(!openSlug); // focus the search box until a doc is opened
    renderReader();
  }

  function open(slug) {
    if (!slug) return;
    openSlug = slug;
    renderList(); // active-row highlight; keeps the reader's "loading" until text lands
    var pane = root.querySelector('.kb-reader');
    if (pane && texts[slug] == null) pane.innerHTML = '<div class="kb-note">loading ' + esc(slug) + '…</div>';
    if (texts[slug] != null) { renderReader(); return; }
    fetchText('kb/' + encodeURIComponent(slug) + '.md').then(function (t) {
      texts[slug] = t;
      if (openSlug === slug) renderReader();
    }).catch(function (e) {
      if (openSlug === slug && pane) {
        pane.innerHTML = '<div class="kb-note">document unavailable: ' + esc(e.message || e) + '</div>';
      }
    });
  }

  function load() {
    return fetchJson('kb/index.json').then(function (ix) {
      index = ix;
      render();
    }).catch(function (e) {
      if (root) root.innerHTML = '<div class="kb-note">kb feed unavailable: ' +
        esc(e.message || e) + ' — run jobs/kb-feed.py</div>';
    });
  }

  window.KBView = {
    init: function (el) {
      root = el;
      if (!document.getElementById('kb-style')) {
        var st = document.createElement('style');
        st.id = 'kb-style';
        st.textContent = STYLE;
        document.head.appendChild(st);
      }
      // ?q=<token> pre-filter (Research view deep-links here)
      try {
        var q = new URLSearchParams(location.search).get('q');
        if (q) query = q;
      } catch (e) { /* very old browser */ }
      load();
    },
    refresh: function () { load(); }
  };
})();
