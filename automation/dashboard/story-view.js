/* story-view — the daily story page (visualization rung 1, step 3).
   Renders today's chapters from the work graph (dashboard/plans.json,
   jobs/plan-feed.py) and the report-queue ledger (dashboard/reports.md).

   Honesty rules are binding: commit-hash footnotes come ONLY from real
   evidence (the feed's last_ceremony_commit plus hex tokens in today's
   report rows); "today" is the UTC date of the feed's own generated
   stamp, never a client-prayed Date; blockers come only from real
   edges; a missing fact renders a dim placeholder, never a fabricated
   value. Display layer only — never governance input. One dry aside
   per section, maximum (MAX_ASIDE; voice rules,
   docs/design/presentation-direction.md). */
(function () {
  'use strict';

  var MAX_ASIDE = 1;
  var HEX = /\b[0-9a-f]{7,40}\b/g;

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function dim(s) {
    return '<span class="dim">' + esc(s || '(not recorded)') + '</span>';
  }
  function aside(txt) {
    return '<aside class="dry-aside">' + esc(txt) + '</aside>';
  }

  function fetchText(url, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 8000);
    return fetch(url, { cache: 'no-store', signal: ctrl.signal })
      .then(function (r) {
        clearTimeout(t);
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.text();
      })
      .catch(function (e) { clearTimeout(t); throw e; });
  }

  /* the error banner carries id "storyerr" — kept literal for the
     contract test;
     showErr never invents a half page. */
  function showErr(msg) {
    var el = document.getElementById("storyerr");
    if (el) { el.textContent = msg; el.hidden = false; }
  }

  /* "today" is the UTC date of the feed's own generated stamp — a
     client-prayed Date could disagree with the ledger's own day. */
  function todayFromStamp(feed) {
    var stamp = feed && feed.generated;
    return (typeof stamp === 'string' && stamp.length >= 10)
      ? stamp.slice(0, 10) : null;
  }

  /* Today's report-queue rows: dashboard/reports.md is a markdown pipe
     table with the ISO timestamp as its first column. */
  function todayRows(reportsText, today) {
    if (!today) return [];
    var prefix = '| ' + today + 'T';
    return reportsText.split('\n').filter(function (line) {
      return line.slice(0, prefix.length) === prefix;
    });
  }

  function rowParts(row) {
    return row.split('|').map(function (x) { return x.trim(); });
  }

  /* Commit-hash footnotes, evidence only: hex tokens in the given
     rows, plus the feed's ceremony commit. */
  function hashesFor(rows, ceremony) {
    var out = {};
    if (ceremony && ceremony.hash) {
      out[ceremony.hash] = { why: 'last ceremony commit', at: ceremony.date };
    }
    rows.forEach(function (row) {
      var m;
      HEX.lastIndex = 0;
      while ((m = HEX.exec(row)) !== null) {
        var h = m[0];
        if (!out[h]) out[h] = { why: 'reported today', at: rowParts(row)[0].slice(0, 16) };
      }
    });
    return out;
  }

  /* Chapters: plans that earned a line today — named in a today row,
     or accepted plans with work still open. High priority first. */
  function chaptersFor(plans, todayRowsMap) {
    return (plans || []).filter(function (p) {
      return todayRowsMap[p.slug] || (p.status === 'accepted' &&
        p.steps_total > (p.steps_done || 0));
    }).sort(function (a, b) {
      return (a.priority === 'high' ? 0 : 1) -
        (b.priority === 'high' ? 0 : 1) || (a.slug < b.slug ? -1 : 1);
    });
  }

  function setBody(id, html) {
    var body = document.getElementById(id);
    if (body) body.innerHTML = html;
    return body;
  }

  function planHref(slug) {
    return '../docs/project/plans/' + encodeURIComponent(slug) + '.plan.md';
  }

  function stepCells(p) {
    var cells = (p.steps || []).map(function (s) {
      var cls = s.done ? 'st-done' : 'st-open';
      return '<span class="' + cls + '" data-step="' + s.n + '" title="' +
        esc((s.done ? 'done: ' : 'open: ') + s.title) +
        '">' + s.n + '</span>';
    });
    if (!cells.length) cells.push(dim('(no step list parsed)'));
    return '<span class="steps-row">' + cells.join('') + '</span>';
  }

  function footnotes(hashMap) {
    return Object.keys(hashMap).map(function (h) {
      var d = hashMap[h];
      return '<sup class="fn" title="' + esc('commit ' + h + ' — ' + d.why +
        (d.at ? ' (' + d.at + ')' : '')) + '">' + esc(h.slice(0, 8)) + '</sup>';
    }).join(' ');
  }

  function planCard(p, hashMap) {
    var pending = (p.edges || []).filter(function (e) {
      if (!e.type || e.type === 'parked-because') return false;
      var src = (p.steps || []).filter(function (s) { return s.n === e.from; })[0];
      return src && !src.done;
    }).map(function (e) {
      return 'step ' + e.from + ' ' + e.type + ' step ' + e.to +
        ' — step ' + e.from + ' is not done';
    });
    var chip = p.status === 'parked' && p.cause
      ? '<span class="cause-chip" title="parked-because (front-matter cause)">' +
        esc(p.cause) + '</span>' : '';
    var blocked = pending.length
      ? ' <span class="blocked-mark" title="' + esc(pending.join('; ')) +
        '">blocked-by ' + pending.length + '</span>' : '';
    var prog = p.steps_total != null
      ? esc(String(p.steps_done || 0) + '/' + String(p.steps_total))
      : dim('(no steps)');
    return '<p class="chapter-line"><a class="fn-link" href="' +
      planHref(p.slug) + '" rel="noopener">' + esc(p.slug) + '</a>' +
      ' <span class="dim">(' + esc(p.status) + ', ' + prog + ')</span>' + chip +
      stepCells(p) + footnotes(hashMap) + blocked + '</p>';
  }

  function renderAccepted(feed) {
    var plans = (feed.plans || []).filter(function (p) {
      return p.status === 'accepted' || p.status === 'executing';
    });
    if (!plans.length) {
      setBody('sec-accepted-body', dim('no accepted plans recorded'));
      return;
    }
    var html = plans.slice(0, 30).map(function (p) {
      return planCard(p, {});
    }).join('');
    if (plans.length > 30) {
      html += '<p class="dim">(30 of ' + plans.length + ' shown)</p>';
    }
    html += MAX_ASIDE >= 1
      ? aside('the estimate-honesty header carries over from the gantt: estimates are projections; step checkmarks are facts')
      : '';
    setBody('sec-accepted-body', html);
  }

  function renderSteps(feed, rows) {
    if (!rows.length) {
      setBody('sec-steps-body', dim('no report-queue rows today'));
      return;
    }
    var map = {};
    (feed.plans || []).forEach(function (p) {
      map[p.slug] = rows.filter(function (row) {
        return row.indexOf(p.slug) !== -1;
      });
    });
    var chapters = chaptersFor(feed.plans, map);
    if (!chapters.length) {
      setBody('sec-steps-body', dim('no plan named in today\'s rows'));
      return;
    }
    var html = chapters.slice(0, 20).map(function (p) {
      return planCard(p, hashesFor(map[p.slug] || [], null));
    }).join('');
    if (chapters.length > 20) {
      html += '<p class="dim">(20 of ' + chapters.length + ' shown)</p>';
    }
    html += aside('a footnote here is a hash that appeared in one of these rows — the ceremony commit only in the accepted section');
    setBody('sec-steps-body', html);
  }

  function renderBlockers(feed, rows) {
    var pend = [];
    var alerts = rows.filter(function (row) {
      return rowParts(row)[1] === 'alert';
    });
    (feed.plans || []).forEach(function (p) {
      (p.edges || []).forEach(function (e) {
        if (!e.type || e.type === 'parked-because') return;
        var src = (p.steps || []).filter(function (s) { return s.n === e.from; })[0];
        if (src && !src.done) {
          pend.push(esc(p.slug) + ': step ' + e.from + ' ' + esc(e.type) +
            ' step ' + e.to + ' — step ' + e.from + ' is not done');
        }
      });
    });
    var html = pend.length
      ? pend.slice(0, 12).map(function (t) {
          return '<p class="blocked-line">' + t + '</p>';
        }).join('') + (pend.length > 12
        ? '<p class="dim">(12 of ' + pend.length + ' shown)</p>' : '')
      : dim('no real blocked-by edges in the work graph');
    html += '<h3>today\'s alerts</h3>';
    if (alerts.length) {
      html += alerts.slice(-15).map(function (row) {
        var parts = rowParts(row);
        return '<p class="alert-row" title="same row the report-queue keeps">' +
          '<span class="tstamp">' + esc(parts[0] || '') + '</span> ' +
          esc(parts[3] || '') + '</p>';
      }).join('');
    } else {
      html += dim('no alert rows today');
    }
    html += aside('blocked-by markers are drawn only from real edges; ' +
      'an alert row here is the same row the queue keeps');
    setBody('sec-blockers-body', html);
  }

  function renderParks(feed) {
    var parked = (feed.plans || []).filter(function (p) {
      return (p.status === 'parked' && p.cause) ||
        (p.edges || []).some(function (e) {
          return e.type === 'parked-because';
        });
    });
    if (!parked.length) {
      setBody('sec-parks-body', dim('no parked plans in the ledger'));
      return;
    }
    var html = parked.slice(-40).map(function (p) {
      var cause = p.cause || ((p.edges || [])
        .filter(function (e) { return e.type === 'parked-because'; })
        .map(function (e) { return e.cause; })[0]) || '(cause not recorded)';
      return '<p class="chapter-line"><a class="fn-link" href="' +
        planHref(p.slug) + '" rel="noopener">' + esc(p.slug) + '</a>' +
        '<span class="cause-chip" title="parked-because (front-matter cause)">' +
        esc(cause) + '</span></p>';
    }).join('');
    if (parked.length > 40) {
      html += '<p class="dim">(40 of ' + parked.length + ' shown)</p>';
    }
    html += aside('a park chip is the plan\'s own front-matter cause, quoted verbatim');
    setBody('sec-parks-body', html);
  }

  function renderAll(feed, reportsText) {
    var stamp = document.getElementById('stamp');
    if (stamp && feed.generated) {
      stamp.textContent = 'plans.json generated ' + feed.generated;
    }
    var today = todayFromStamp(feed);
    if (!today) {
      showErr('plans.json unreadable or missing its generated stamp — failing closed instead of rendering the wrong day');
      return;
    }
    var rows = todayRows(reportsText, today);
    renderAccepted(feed);
    renderSteps(feed, rows);
    renderBlockers(feed, rows);
    renderParks(feed);
  }

  function refresh() {
    var err = document.getElementById("storyerr");
    if (err) err.hidden = true;
    var stamp = document.getElementById('stamp');
    if (stamp) stamp.textContent = 'awaiting feeds…';
    fetchText("plans.json")
      .then(function (t) { return JSON.parse(t); })
      .then(function (feed) {
        return fetchText("reports.md").then(function (text) {
          return { feed: feed, text: text };
        });
      })
      .then(function (both) { renderAll(both.feed, both.text); })
      .catch(function (e) {
        showErr('story feed unreachable (' + e + ') — nothing is rendered rather than a half page; press refresh to retry');
        if (stamp) stamp.textContent = 'feed unreachable';
      });
  }

  document.getElementById('refresh-btn').addEventListener('click', refresh);
  refresh();
})();
