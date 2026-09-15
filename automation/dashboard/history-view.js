/* history-view — the history spine view (View A, .agent-scratch/
   swarm-resume/viz-history-work-parent.md). Renders the merged history/1
   feed (GET /history.json, jobs/history-feed.py) as a vertical newest-
   first stream: ts + source chip (gitlog/report/records/journal) +
   summary, with optional kind chip, author, and short-hash evidence.
   Source filter chips + kind filter chips are client-side (the 7d window
   itself stays server-side in the feed, hist-renders rule 5).

   Honesty rules are binding (same contract as story-view): the gate is
   exact — only schema === 'history/1' with an Array of entries renders;
   anything else fails closed into the #histerr banner instead of
   rendering a wrong page (coordinator resolution 2026-09-15: the
   envelope is pinned to exactly {schema, entries}, so there is no
   feed-level stamp — anchoring comes from the entries' own ts extent,
   shown as the freshness caption; NO client dates anywhere).
   Evidence links only through the jailed /hngh-docs/docs/ route and
   ONLY for repo-relative docs/ refs — gitlog rows link the short hash;
   anything else renders as plain text. Cap + "(N of M shown)" overflow
   marker at 100 rows. Refresh is manual (#refresh-btn) plus one load on
   start — the same no-poll pattern story-view uses, no raw timer and no
   auto-refresh helper.
   Pure helpers (feedOk/tsExtent/visibleEntries/rowHtml/renderRows/
   overflowLine) carry no DOM references so the headless contract test
   can execute them via node (seam above the boot marker).
   All styles live in one owned <style> tag injected at mount —
   style.css untouched. Display layer only — never governance input. */
(function () {
  'use strict';

  var DISPLAY_CAP = 100;

  /* ---- pure helpers (headless seam: keep DOM-free above boot) ---- */
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function dim(s) {
    return '<span class="hv-dim">' + esc(s || '(not recorded)') + '</span>';
  }

  /* Feed gate, exact (todayFromStamp's honesty role, feed-shaped): only
     the pinned history/1 envelope with an entries array renders. The
     envelope surface is exactly {schema, entries} — there is no
     feed-level stamp, so anchoring comes from the entries themselves. */
  function feedOk(feed) {
    return !!feed && feed.schema === 'history/1' &&
      Array.isArray(feed.entries);
  }

  /* Anchoring caption from the entries' own Z-normalized ts values
     (lexicographic compare is exact for that form); null when no usable
     ts exists — the empty envelope renders the empty state, which is
     valid per the producer spec. Pure: no Date anywhere. */
  function tsExtent(entries) {
    if (!Array.isArray(entries)) return null;
    var min = null, max = null;
    entries.forEach(function (e) {
      var ts = e && e.ts;
      if (typeof ts !== 'string' || ts.length < 10) return;
      if (min === null || ts < min) min = ts;
      if (max === null || ts > max) max = ts;
    });
    return min === null ? null : { oldest: min, newest: max };
  }

  /* Client-side filters: source ("gitlog"|"report"|"records"|"journal"
     |"") and kind ("progress"|"alert"|...|""). Order from the feed is
     kept (already ts desc, key asc). */
  function visibleEntries(feed, source, kind) {
    var rows = (feed && feed.entries) || [];
    return rows.filter(function (e) {
      if (source && e.source !== source) return false;
      if (kind && e.kind !== kind) return false;
      return true;
    });
  }

  /* Evidence link, jailed: only a repo-relative docs/ path earns an
     href (through the /hngh-docs/docs/ jail); anything else renders as
     plain text. Never a raw anchor to an arbitrary string. */
  function refHtml(e) {
    var ref = e.ref;
    if (typeof ref === 'string' && ref.startsWith("docs/")) {
      var jail = '/hngh-docs/docs/' + encodeURIComponent(ref);
      return '<a class="hv-ref" href="' + esc(jail) +
        '" rel="noopener">ref</a>';
    }
    return ref ? dim(ref) : '';
  }

  function rowHtml(e) {
    var author = e.author ? ' <span class="hv-dim">(' + esc(e.author) +
      ')</span>' : '';
    var kind = e.kind ? '<span class="hv-chip hv-chip-kind" title="kind">' +
      esc(e.kind) + '</span>' : '';
    var summary = e.short
      ? '<a class="hv-short" href="/hngh-docs/docs/' +
        encodeURIComponent('gitlog/' + e.short) + '" rel="noopener" title="' +
        esc('commit ' + e.short) + '">' + esc(e.summary) + '</a>'
      : esc(e.summary);
    return '<p class="hv-row" data-key="' + esc(e.key) + '">' +
      '<span class="hv-ts">' + esc(e.ts) + '</span>' +
      '<span class="hv-chip hv-chip-' + esc(e.source) + '">' +
      esc(e.source) + '</span>' + kind + ' ' + summary + author +
      refHtml(e) + '</p>';
  }

  function renderRows(rows, cap) {
    if (!rows.length) {
      return '<div class="hv-empty">no history entries match</div>';
    }
    var shown = rows.slice(0, cap || DISPLAY_CAP);
    return shown.map(rowHtml).join('') + overflowLine(rows, cap);
  }

  function overflowLine(rows, cap) {
    cap = cap || DISPLAY_CAP;
    return rows.length > cap
      ? '<p class="hv-dim">(' + cap + ' of ' + rows.length + ' shown)</p>'
      : '';
  }

  // ---- boot ----
  // (DOM from here down; the headless node seam ends above)

  /* owned <style> tag: every hv- rule rides this string, injected once
     at mount — style.css is never touched (graph/sessions convention) */
  var CSS = '';
  CSS += '.hv-toolbar{display:flex;gap:6px;flex-wrap:wrap;align-items:center;padding:6px 0;border-bottom:1px solid var(--line);}\n';
  CSS += '.hv-fchip{background:transparent;border:1px solid var(--line);color:var(--muted);font-size:11px;padding:1px 7px;cursor:pointer;}\n';
  CSS += '.hv-fchip.on{color:var(--ink);border-color:var(--accent);background:rgba(47,129,247,.12);}\n';
  CSS += '.hv-fsep{flex:0 0 12px;}\n';
  CSS += '.hv-row{margin:2px 0;font-size:12px;line-height:1.5;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}\n';
  CSS += '.hv-ts{color:var(--dim);font-size:11px;margin-right:6px;}\n';
  CSS += '.hv-dim{color:var(--dim);}\n';
  CSS += '.hv-chip{display:inline-block;padding:0 6px;margin-right:5px;border:1px solid var(--line);border-radius:2px;font-size:10px;line-height:16px;letter-spacing:.04em;text-transform:uppercase;color:var(--muted);white-space:nowrap;}\n';
  CSS += '.hv-chip-gitlog{color:var(--accent);border-color:var(--accent);}\n';
  CSS += '.hv-chip-report{color:var(--warn);border-color:var(--warn);}\n';
  CSS += '.hv-chip-records{color:var(--violet,#a371f7);border-color:var(--violet,#a371f7);}\n';
  CSS += '.hv-chip-journal{color:var(--ok);border-color:var(--ok);}\n';
  CSS += '.hv-chip-kind{font-size:9px;}\n';
  CSS += '.hv-ref,.hv-short{color:var(--accent);text-decoration:none;}\n';
  CSS += '.hv-ref:hover,.hv-short:hover{text-decoration:underline;}\n';
  CSS += '.hv-empty{color:var(--dim);font-size:12px;padding:6px 0;}\n';

  function injectStyle() {
    if (document.getElementById('hv-style')) return;
    var st = document.createElement('style');
    st.id = 'hv-style';
    st.textContent = CSS;
    document.head.appendChild(st);
  }

  var filters = { source: '', kind: '' };

  function renderAll(feed) {
    var rows = visibleEntries(feed, filters.source, filters.kind);
    setBody(renderRows(rows, DISPLAY_CAP));
    var extent = tsExtent(rows);
    var caption = extent
      ? ' · spanning ' + extent.oldest + ' .. ' + extent.newest : '';
    var sum = document.getElementById('hist-sum');
    if (sum) sum.textContent = (feed.entries || []).length + ' entries · ' +
      rows.length + ' shown' + caption;
    var stampEl = document.getElementById('stamp');
    if (stampEl) {
      stampEl.textContent = extent
        ? 'spanning ' + extent.oldest + ' .. ' + extent.newest : '';
    }
  }

  function setBody(html) {
    var body = document.getElementById('hist-body');
    if (body) body.innerHTML = html;
  }

  /* the error banner carries id "histerr" — kept literal for the
     contract test; showErr never invents a half page. */
  function showErr(msg) {
    var el = document.getElementById("histerr");
    if (el) { el.textContent = msg; el.hidden = false; }
  }

  function fetchJson(url, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 10000);
    return fetch(url, { cache: 'no-store', signal: ctrl.signal })
      .then(function (r) {
        clearTimeout(t);
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.json();
      })
      .catch(function (e) { clearTimeout(t); throw e; });
  }

  function refresh() {
    var err = document.getElementById("histerr");
    if (err) err.hidden = true;
    var sum = document.getElementById('hist-sum');
    if (sum) sum.textContent = 'awaiting feed…';
    fetchJson("history.json")
      .then(function (feed) {
        if (!feedOk(feed)) {
          // fail closed: only the pinned history/1 envelope renders
          showErr('history.json is not a valid history/1 envelope — failing closed instead of rendering an unanchored page');
          if (sum) sum.textContent = 'feed unusable';
          return;
        }
        renderAll(feed);
      })
      .catch(function (e) {
        showErr('history feed unreachable (' + e + ') — nothing is rendered rather than a half page; press refresh to retry');
        if (sum) sum.textContent = 'feed unreachable';
      });
  }

  function chip(label, key, value, on) {
    return '<button type="button" class="hv-fchip' + (on ? ' on' : '') +
      '" data-' + key + '="' + esc(value) + '" aria-pressed="' + (on ? 'true' : 'false') +
      '" title="filter ' + esc(key) + '">' + esc(label) + '</button>';
  }

  function mount(el) {
    var bar = el.querySelector('.hv-toolbar') || el;
    bar.addEventListener('click', function (ev) {
      var b = ev.target.closest ? ev.target.closest('.hv-fchip') : null;
      if (!b) return;
      if (b.dataset.source !== undefined) {
        filters.source = filters.source === b.dataset.source ? '' : b.dataset.source;
      } else if (b.dataset.kind !== undefined) {
        filters.kind = filters.kind === b.dataset.kind ? '' : b.dataset.kind;
      } else {
        return;
      }
      Array.prototype.forEach.call(bar.querySelectorAll('.hv-fchip'), function (c) {
        var on = (c.dataset.source !== undefined && c.dataset.source === filters.source) ||
                 (c.dataset.kind !== undefined && c.dataset.kind === filters.kind);
        c.classList.toggle('on', on);
        c.setAttribute('aria-pressed', String(on));
      });
      refresh();
    });
  }

  var SOURCES = ['gitlog', 'report', 'records', 'journal'];
  var KINDS = ['progress', 'alert'];

  function init(el) {
    injectStyle();
    var bar = el.querySelector('.hv-toolbar');
    if (bar && !bar.childElementCount) {
      var html = chip('all sources', 'source', '', true);
      SOURCES.forEach(function (s) {
        html += chip(s, 'source', s, false);
      });
      html += '<span class="hv-fsep"></span>' + chip('all kinds', 'kind', '', true);
      KINDS.forEach(function (k) {
        html += chip(k, 'kind', k, false);
      });
      bar.innerHTML = html;
    }
    mount(el);
    var rb = document.getElementById('refresh-btn');
    if (rb) rb.addEventListener('click', refresh);
    refresh();
  }

  /* mounted by app.js into index.html#p-history > #history-root (lazy
     init on first tab activation, refresh() on later ones); also runs
     standalone from history.html (window.HistoryView missing there). */
  if (typeof window !== 'undefined' && window.HnghTabs !== undefined) {
    window.HistoryView = { init: init, refresh: refresh };
  } else if (typeof document !== 'undefined') {
    var rootEl = document.getElementById('history-root') || document.body;
    init(rootEl);
  }

  /* headless seam for the contract test (no DOM in these) */
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { generatedAt: generatedAt, visibleEntries: visibleEntries,
      rowHtml: rowHtml, renderRows: renderRows, overflowLine: overflowLine };
  }
})();
