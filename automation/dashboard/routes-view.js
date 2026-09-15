/* routes-view — the research-routes map view (the first game-layer
   surface, .agent-scratch/swarm-resume/viz-history-work-parent.md View A
   sibling). Renders the routes/1 feed (GET /research-routes.json,
   jobs/research-routes.py) as ROUTES across a map: each research line is
   a polyline traveling a time axis (x = the route's own transition
   dates), in a lane per lifecycle stage (reviewed/crystallized/planned), and
   ends in a terminus node shaped by its disposition action — adopted =
   filled circle, killed = X mark, parked = hollow circle, open = small
   dot at the map origin (no dated terminus). Routes carrying an active
   harvested lesson (d1-harvest's research-lessons.tsv) wear a lesson
   marker on their terminus.

   Honesty rules are binding (same contract as history-view): the gate is
   exact — only schema === 'routes/1' with a routes array renders;
   anything else fails closed into the #routeserr banner instead of
   rendering a wrong map. The map's date span derives ONLY from the
   payload (the feed's own `generated` stamp plus the routes' dated
   termini/segments); NO client dates anywhere. Cap at 100 routes with
   the "(N of M shown)" overflow line. Refresh is manual (#refresh-btn)
   plus one load on start — the story/history no-poll pattern.
   Pure helpers (feedOk/routeSpan/visibleRoutes/layout/routeSvg/
   renderRoutes/overflowLine) carry no DOM references so the headless
   contract test can execute them via node (seam above the boot marker).
   All styles live in one owned <style> tag injected at mount — style.css
   untouched. Display layer only — never governance input. */
(function () {
  'use strict';

  var DISPLAY_CAP = 100;
  /* map geometry (SVG viewBox units; the <svg> scales responsively);
     PAD_L leaves room for the lane labels left of the polylines */
  var MAP_W = 1000, MAP_H = 300, LANE_H = 56, PAD_L = 64, PAD_R = 190;

  /* ---- pure helpers (headless seam: keep DOM-free above boot) ---- */
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function dim(s) {
    return '<span class="rv-dim">' + esc(s || '(not recorded)') + '</span>';
  }

  /* Feed gate, exact (story-view's todayFromStamp honesty role,
     feed-shaped): only the pinned routes/1 envelope with a routes array
     renders. */
  function feedOk(feed) {
    return !!feed && feed.schema === 'routes/1' &&
      Array.isArray(feed.routes);
  }

  /* Map time span from the payload only: [first, last] across every
     dated terminus and segment of the shown routes. Lexicographic
     compare is exact for Z-normalized timestamps. Null fields when the
     payload carries no dates at all (the empty envelope is valid; the
     feed's `generated` stamp is shown in the summary line, it does not
     extend the map). Pure: no Date.now, no client clock anywhere. */
  function routeSpan(feed, routes) {
    var min = null, max = null;
    (routes || []).forEach(function (r) {
      if (r && r.terminus && typeof r.terminus.date === 'string' &&
          r.terminus.date.length >= 10) {
        if (min === null || r.terminus.date < min) min = r.terminus.date;
        if (max === null || r.terminus.date > max) max = r.terminus.date;
      }
      if (r && Array.isArray(r.segments)) {
        r.segments.forEach(function (d) {
          if (typeof d !== 'string' || d.length < 10) return;
          if (min === null || d < min) min = d;
          if (max === null || d > max) max = d;
        });
      }
    });
    if (min === null && max === null) return { first: null, last: null };
    return { first: min, last: max };
  }

  /* Client-side filters: status family ("reviewed"|"planned"|...) and
     harvested ("yes"|""). Order from the feed is kept (newest-wins). */
  function visibleRoutes(feed, status, harvested) {
    var rows = (feed && feed.routes) || [];
    return rows.filter(function (r) {
      if (status && r.status !== status) return false;
      if (harvested === 'yes' && r.harvested !== true) return false;
      return true;
    });
  }

  /* Lane per lifecycle stage (33-research-beat.sh's canonical line
     lifecycle planned -> expanding -> contracting -> crystallized ->
     reviewed): early exploration lanes (planned/expanding/contracting)
     share the planned lane, crystallized and reviewed get their own.
     The map reads top = carried-a-lesson-review, bottom = fresh. */
  function familyOf(status) {
    if (status === 'crystallized') return 'crystallized';
    if (status === 'reviewed') return 'reviewed';
    return 'planned';
  }
  var FAMILY_ORDER = ['reviewed', 'crystallized', 'planned'];

  /* x(t): date string -> pixel, linear across [span.first, span.last];
     t before the span start clamps to the left padding. */
  function xOf(t, span, width) {
    if (typeof t !== 'string' || t.length < 10) return PAD_L;
    if (!span || !span.first || !span.last || span.last <= span.first) {
      return PAD_L;
    }
    var inner = width - PAD_L - PAD_R;
    if (t <= span.first) return PAD_L;
    if (t >= span.last) return PAD_L + inner;
    var frac = (t.slice(0, 10) < span.first.slice(0, 10))
      ? 0 : (Date.parse(t) - Date.parse(span.first)) /
            (Date.parse(span.last) - Date.parse(span.first));
    if (!isFinite(frac)) return PAD_L;
    return PAD_L + frac * inner;
  }

  /* Pure geometry: one point set per route {id, lane, row, y, pts, x}.
     `lane` is the family band index (done=0, killed=1, parked=2,
     planned=3); `row` is the sub-row within the band cycling 0..3 so
     dense families (74 reviewed routes) stagger instead of stacking one
     line. The polyline visits each segment date's x; open routes (no
     dated terminus) run as a short stub from the map origin.
     Deterministic: no Date, no Math.random. */
  function layout(routes, span, width, laneH) {
    width = width || MAP_W;
    laneH = laneH || LANE_H;
    var counts = {};
    FAMILY_ORDER.forEach(function (f) { counts[f] = 0; });
    var out = [];
    routes.forEach(function (r) {
      if (!r || typeof r.id !== 'string') return;
      var fam = familyOf(r.status);
      var fi = FAMILY_ORDER.indexOf(fam);
      var row = counts[fam]++;
      var y = 26 + fi * laneH + (row % 4) * 9;
      var pts = [];
      var dates = (r.segments || []).filter(function (d) {
        return typeof d === 'string' && d.length >= 10;
      });
      if (!dates.length) {
        // a route with no dated transitions: a short stub from the
        // origin so it still appears on the map
        pts = [PAD_L, PAD_L + 26];
      } else {
        dates.forEach(function (d) { pts.push(xOf(d, span, width)); });
      }
      var termX = (r.terminus && r.terminus.date)
        ? xOf(r.terminus.date, span, width) : PAD_L;
      pts.push(termX);
      out.push({
        id: r.id,
        family: fam,
        lane: fi,
        row: row % 4,
        y: y,
        pts: pts,
        x: termX
      });
    });
    return out;
  }

  function mapHeight(geo, laneH) {
    laneH = laneH || LANE_H;
    var maxLane = 0;
    geo.forEach(function (g) { if (g.lane > maxLane) maxLane = g.lane; });
    return 26 + (maxLane + 1) * laneH + 10;
  }

  /* Terminus node shape by action: adopted = filled circle,
     killed = X, parked = hollow circle, open = small dot at origin. */
  function terminusSvg(r, g) {
    var action = r.terminus && r.terminus.action ? r.terminus.action : 'open';
    var cls = 'rv-term rv-term-' + esc(action);
    var x = g.x, y = g.y;
    if (action === 'killed') {
      return '<g class="' + cls + '">' +
        '<line x1="' + (x - 5) + '" y1="' + (y - 5) + '" x2="' + (x + 5) +
        '" y2="' + (y + 5) + '"/>' +
        '<line x1="' + (x - 5) + '" y1="' + (y + 5) + '" x2="' + (x + 5) +
        '" y2="' + (y - 5) + '"/></g>';
    }
    if (action === 'open') {
      return '<circle class="' + cls + '" cx="' + x + '" cy="' + y +
        '" r="2.5"/>';
    }
    return '<circle class="' + cls + '" cx="' + x + '" cy="' + y +
      '" r="' + (action === 'parked' ? 4 : 4.5) + '"/>';
  }

  /* Evidence link, jailed (history-view refHtml parity): only a
     repo-relative docs/ path earns an href through the /hngh-docs/docs/
     jail; anything else renders as plain text. routes/1 carries no ref
     today — this exists for the additive lane, fail closed. */
  function refHtml(r) {
    var ref = r && r.ref;
    if (typeof ref === 'string' && ref.startsWith("docs/")) {
      var jail = '/hngh-docs/docs/' + encodeURIComponent(ref);
      return '<a class="rv-ref" href="' + esc(jail) +
        '" rel="noopener">ref</a>';
    }
    return ref ? dim(ref) : '';
  }

  /* One route's SVG: a polyline along its segment dates, terminus node
     shaped by action, plus the lesson marker and the (html-escaped)
     title label. All numbers in the geometry are produced by layout()
     from payload data; the only free strings (id, title) are escaped. */
  function routeSvg(r, g) {
    var ptsAttr = g.pts.map(function (x, i) {
      return x + ',' + g.y;
    }).join(' ');
    var label = esc(r.title || r.id);
    var harvest = r.harvested
      ? '<circle class="rv-mark-harvest" cx="' + (g.x + 8) + '" cy="' +
        (g.y - 8) + '" r="3"/>'
      : '';
    return '<g class="rv-route rv-route-' + esc(g.family) + '" data-id="' +
      esc(r.id) + '">' +
      '<polyline points="' + ptsAttr + '"/>' +
      terminusSvg(r, g) + harvest +
      '<text class="rv-label" x="' + (g.x + 14) + '" y="' + (g.y + 4) +
      '">' + label + '</text>' + refHtml(r) +
      '<title>' + esc(r.id) + ' — ' + esc(r.status) +
      (r.harvested ? ' — lesson harvested' : '') + '</title>' +
      '</g>';
  }

  function overflowLine(routes, cap) {
    cap = cap || DISPLAY_CAP;
    return routes.length > cap
      ? '<p class="rv-dim">(' + cap + ' of ' + routes.length + ' shown)</p>'
      : '';
  }

  function renderRoutes(routes, span, cap) {
    if (!routes.length) {
      return '<div class="rv-empty">no routes match — no research lines ' +
        'in the feed match the current filters</div>';
    }
    var shown = routes.slice(0, cap || DISPLAY_CAP);
    var geo = layout(shown, span, MAP_W, LANE_H);
    var h = mapHeight(geo, LANE_H);
    var svg = '<svg class="rv-map" viewBox="0 0 ' + MAP_W + ' ' + h +
      '" preserveAspectRatio="xMinYMin meet" role="img" ' +
      'aria-label="research routes map">';
    FAMILY_ORDER.forEach(function (fam) {
      var ys = geo.filter(function (g) { return g.family === fam; })
        .map(function (g) { return g.y; });
      if (!ys.length) return;
      svg += '<text class="rv-lane-label" x="' + (PAD_L - 8) + '" y="' +
        (Math.min.apply(null, ys) + 4) + '" text-anchor="end">' +
        esc(fam) + '</text>';
    });
    svg += shown.map(function (r, i) {
      return routeSvg(r, geo[i]);
    }).join('');
    svg += '</svg>';
    return svg + overflowLine(routes, cap);
  }

  function renderAll(feed) {
    var routes = visibleRoutes(feed, filters.status, filters.harvested);
    var span = routeSpan(feed, routes);
    setBody(renderRoutes(routes, span, DISPLAY_CAP));
    var sum = document.getElementById('routes-sum');
    if (sum) {
      var stamp = typeof feed.generated === 'string' ? feed.generated : '';
      sum.textContent = (feed.routes || []).length + ' routes · ' +
        routes.length + ' shown · generated ' + stamp;
    }
    var stampEl = document.getElementById('stamp');
    if (stampEl) {
      stampEl.textContent = span.first
        ? 'spanning ' + span.first.slice(0, 10) + ' .. ' +
          span.last.slice(0, 10) : '';
    }
  }

  function setBody(html) {
    var body = document.getElementById('routes-body');
    if (body) body.innerHTML = html;
  }

  /* the error banner carries id "routeserr" — kept literal for the
     contract test; showErr never invents a half page. */
  function showErr(msg) {
    var el = document.getElementById("routeserr");
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
    var err = document.getElementById("routeserr");
    if (err) err.hidden = true;
    var sum = document.getElementById('routes-sum');
    if (sum) sum.textContent = 'awaiting feed…';
    fetchJson("research-routes.json")
      .then(function (feed) {
        if (!feedOk(feed)) {
          // fail closed: only the pinned routes/1 envelope renders
          showErr('research-routes.json is not a valid routes/1 envelope — failing closed instead of rendering an unanchored map');
          if (sum) sum.textContent = 'feed unusable';
          return;
        }
        renderAll(feed);
      })
      .catch(function (e) {
        showErr('routes feed unreachable (' + e + ') — nothing is rendered rather than a half map; press refresh to retry');
        if (sum) sum.textContent = 'feed unreachable';
      });
  }

  function chip(label, key, value, on) {
    return '<button type="button" class="rv-fchip' + (on ? ' on' : '') +
      '" data-' + key + '="' + esc(value) + '" aria-pressed="' +
      (on ? 'true' : 'false') + '" title="filter ' + esc(key) + '">' +
      esc(label) + '</button>';
  }

  // ---- boot ----
  // (DOM from here down; the headless node seam ends above)

  /* owned <style> tag: every rv- rule rides this string, injected once
     at mount — style.css is never touched (graph/history convention) */
  var CSS = '';
  CSS += '.rv-toolbar{display:flex;gap:6px;flex-wrap:wrap;align-items:center;padding:6px 0;border-bottom:1px solid var(--line);}\n';
  CSS += '.rv-fchip{background:transparent;border:1px solid var(--line);color:var(--muted);font-size:11px;padding:1px 7px;cursor:pointer;}\n';
  CSS += '.rv-fchip.on{color:var(--ink);border-color:var(--accent);background:rgba(47,129,247,.12);}\n';
  CSS += '.rv-fsep{flex:0 0 12px;}\n';
  CSS += '.rv-map{width:100%;height:auto;display:block;}\n';
  CSS += '.rv-map .rv-route polyline{fill:none;stroke:var(--muted);stroke-width:1.5;stroke-linejoin:round;stroke-linecap:round;opacity:.85;}\n';
  CSS += '.rv-route-reviewed polyline{stroke:var(--ok);}\n';
  CSS += '.rv-route-crystallized polyline{stroke:var(--violet,#a371f7);}\n';
  CSS += '.rv-route-planned polyline{stroke:var(--accent);stroke-dasharray:2 3;}\n';
  CSS += '.rv-term{fill:var(--ink);stroke:var(--ink);stroke-width:1.5;}\n';
  CSS += '.rv-term-adopted{fill:var(--ok);}\n';
  CSS += '.rv-term-killed line{stroke:var(--warn);stroke-width:2;}\n';
  CSS += '.rv-term-parked{fill:none;stroke:var(--muted);}\n';
  CSS += '.rv-term-open{fill:var(--dim);stroke:none;}\n';
  CSS += '.rv-mark-harvest{fill:var(--violet,#a371f7);stroke:none;}\n';
  CSS += '.rv-label{fill:var(--muted);font-size:10px;}\n';
  CSS += '.rv-lane-label{fill:var(--dim);font-size:10px;letter-spacing:.08em;text-transform:uppercase;}\n';
  CSS += '.rv-ref{fill:var(--accent);}\n';
  CSS += '.rv-dim{color:var(--dim);}\n';
  CSS += '.rv-empty{color:var(--dim);font-size:12px;padding:6px 0;}\n';

  function injectStyle() {
    if (document.getElementById('rv-style')) return;
    var st = document.createElement('style');
    st.id = 'rv-style';
    st.textContent = CSS;
    document.head.appendChild(st);
  }

  var filters = { status: '', harvested: '' };
  var STATUSES = ['reviewed', 'crystallized', 'contracting', 'expanding',
                  'planned'];

  function mount(el) {
    var bar = el.querySelector('.rv-toolbar') || el;
    bar.addEventListener('click', function (ev) {
      var b = ev.target.closest ? ev.target.closest('.rv-fchip') : null;
      if (!b) return;
      if (b.dataset.status !== undefined) {
        filters.status = filters.status === b.dataset.status ? '' : b.dataset.status;
      } else if (b.dataset.harvested !== undefined) {
        filters.harvested = filters.harvested === b.dataset.harvested ? '' : b.dataset.harvested;
      } else {
        return;
      }
      Array.prototype.forEach.call(bar.querySelectorAll('.rv-fchip'), function (c) {
        var on = (c.dataset.status !== undefined && c.dataset.status === filters.status) ||
                 (c.dataset.harvested !== undefined && c.dataset.harvested === filters.harvested);
        c.classList.toggle('on', on);
        c.setAttribute('aria-pressed', String(on));
      });
      refresh();
    });
  }

  function init(el) {
    injectStyle();
    var bar = el.querySelector('.rv-toolbar');
    if (bar && !bar.childElementCount) {
      var html = chip('all statuses', 'status', '', true);
      STATUSES.forEach(function (s) {
        html += chip(s, 'status', s, false);
      });
      html += '<span class="rv-fsep"></span>' +
        chip('harvested', 'harvested', 'yes', false);
      bar.innerHTML = html;
    }
    mount(el);
    var rb = document.getElementById('refresh-btn');
    if (rb) rb.addEventListener('click', refresh);
    refresh();
  }

  /* mounted by app.js into index.html#p-routes > #routes-root (lazy init
     on first tab activation, refresh() on later ones); also runs
     standalone from routes.html (window.HnghTabs missing there). */
  if (typeof window !== 'undefined' && window.HnghTabs !== undefined) {
    window.RoutesView = { init: init, refresh: refresh };
  } else if (typeof document !== 'undefined') {
    var rootEl = document.getElementById('routes-root') || document.body;
    init(rootEl);
  }

  /* headless seam for the contract test (no DOM in these) */
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { feedOk: feedOk, routeSpan: routeSpan,
      visibleRoutes: visibleRoutes, layout: layout,
      routeSvg: routeSvg, renderRoutes: renderRoutes,
      overflowLine: overflowLine };
  }
})();
