/* system-view — the System tab: CachyOS observability + safe operator ops,
   mounted into index.html#p-system > #system-root by app.js (window.SystemView =
   {init, refresh}; init on first tab activation, refresh() on later ones
   plus its own 60s poll). Renders dashboard/system-ops.json
   (jobs/system-feed.py): pending pacman updates, package/orphan counts,
   systemd failed units, per-mount disk bars, memory, 24h journal errors,
   temperatures, a network summary, the last config-backup ledger rows,
   and dashboard session counts.

   STATIC compact grid — no GridStack, no drag, no resize handles, no
   persisted layout: every card autosizes to its content
   (grid-auto-rows: auto), so nothing is ever cut off; cards collapse to
   two columns <=1100px and one <=560px.

   Safe ops (server-enforced, dashboard-server.py; every action appends a
   system-op line to agent-handoffs.md):
     - per-card refresh: re-runs the whole feed probe
       (POST /system/refresh; the probe script is one unit — a card
       refresh therefore refreshes every card's data, honestly).
     - per-unit "reset" on USER failed units: POST /system/reset-failed
       -> systemctl --user reset-failed <unit> (clears failed STATE;
       stops nothing). System-scope units show no button — no authority.
     - "run backup now": POST /system/backup-now -> the governed
       config-backup agent-configs lane (validates all sources,
       secret-scans fail-closed, then commits + pushes).
   No package/config mutation is ever offered: pacman -Syu and friends
   are a future governed rung (stated in the footer note). All styles
   live in one owned <style> tag — style.css is not touched. */
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
  /* POST that resolves {status, json} even on non-2xx: the server's
     500s carry the operation result (rc, refused tail) in the body. */
  function post(url, body, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 320000);
    return fetch(url, {
      method: 'POST', cache: 'no-store', signal: ctrl.signal,
      headers: { 'Content-Type': 'application/json',
        'X-Hngh-Token': (window.HnghOps ? window.HnghOps.token() : '') },
      body: JSON.stringify(body || {})
    }).then(function (r) {
      clearTimeout(t);
      if (r.status === 403 && window.HnghOps) window.HnghOps.expired();
      return r.json().then(function (j) { return { status: r.status, json: j }; });
    }).catch(function (e) { clearTimeout(t); throw e; });
  }
  function ago(ts) {
    var t = Date.parse(ts);
    if (isNaN(t)) return String(ts);
    var s = (Date.now() - t) / 1000;
    if (s < 90) return Math.round(s) + 's ago';
    if (s < 5400) return Math.round(s / 60) + 'm ago';
    return (Math.round(s / 3600 * 10) / 10) + 'h ago';
  }

  /* ---- owned styles (sys- prefix) ---- */
  var STYLE = [
    '.sys-note{color:var(--muted);font-size:11.5px;padding:2px 2px 10px;margin:0}',
    '.sys-note .sys-status{color:var(--accent)}',
    '.sys-cards{display:grid;grid-template-columns:repeat(12,1fr);gap:10px;',
    '  align-items:stretch;grid-auto-rows:auto}',
    '.sys-cards>.c2{grid-column:span 2}',
    '.sys-cards>.c4{grid-column:span 4}',
    '.sys-cards>.c8{grid-column:span 8}',
    '.sys-card{border:1px solid var(--line);border-radius:0;background:var(--panel);',
    '  padding:8px 10px;min-width:0}',
    '.sys-card h3{margin:0 0 6px;font-size:10.5px;font-weight:600;letter-spacing:.08em;',
    '  text-transform:uppercase;color:var(--muted);display:flex;align-items:center;gap:8px}',
    '.sys-card h3 .sys-btn{margin-left:auto}',
    '.sys-btn{font-size:10px;padding:1px 8px;white-space:nowrap;cursor:pointer;',
    '  text-transform:none;letter-spacing:0}',
    '.sys-btn:disabled{opacity:.5;cursor:default}',
    '.sys-unit-input{width:100%;box-sizing:border-box;background:transparent;',
    '  color:var(--ink);border:1px solid var(--line);border-radius:0;padding:4px 8px;',
    '  font:inherit;font-size:11.5px;margin-bottom:6px}',
    '.sys-big{font-size:22px;line-height:1.2;color:var(--ink)}',
    '.sys-big.ok{color:var(--ok)}',
    '.sys-big.warn{color:var(--warn)}',
    '.sys-big.bad{color:var(--danger)}',
    '.sys-sub{color:var(--dim);font-size:11px;margin-top:3px}',
    '.sys-list{margin:6px 0 0;padding:0;list-style:none;font-size:11.5px;color:var(--muted)}',
    '.sys-list code{color:var(--ink)}',
    '.sys-list li{display:flex;align-items:baseline;gap:6px;padding:1px 0;min-width:0}',
    '.sys-list li>span{flex:1;min-width:0;overflow-wrap:anywhere}',
    'details.sys-pkgs{margin-top:6px;font-size:11.5px}',
    'details.sys-pkgs summary{cursor:pointer;color:var(--accent);user-select:none}',
    '.sys-bar{height:7px;border-radius:0;background:rgba(127,127,127,.15);',
    '  overflow:hidden;margin:5px 0 2px}',
    '.sys-fill{height:100%;border-radius:0;background:var(--accent)}',
    '.sys-fill.warn{background:var(--warn)}',
    '.sys-fill.bad{background:var(--danger)}',
    '.sys-row{display:flex;justify-content:space-between;gap:8px;font-size:11.5px;',
    '  color:var(--muted);margin-top:6px}',
    '.sys-row b{color:var(--ink);font-weight:600}',
    '.sys-hint{color:var(--dim);font-size:10.5px;margin-top:6px;font-family:monospace}',
    '.sys-temp{display:flex;justify-content:space-between;font-size:11.5px;',
    '  color:var(--muted);padding:1px 0}',
    '.sys-tag{font-size:11px;padding:0 5px;border-radius:0;white-space:nowrap;',
    '  border:1px solid var(--line)}',
    '.sys-tag.ok{color:var(--ok);border-color:var(--ok)}',
    '.sys-tag.bad{color:var(--danger);border-color:var(--danger)}',
    '.sys-foot{color:var(--dim);font-size:10.5px;padding:8px 2px 0;margin:0}',
    '.sys-err{color:var(--danger);font-size:12px;padding:6px 2px}',
    '@media (max-width:1100px){.sys-cards{grid-template-columns:repeat(2,1fr)}',
    '  .sys-cards>.c2,.sys-cards>.c4,.sys-cards>.c8{grid-column:auto}}',
    '@media (max-width:560px){.sys-cards{grid-template-columns:1fr}}'
  ].join('\n');

  /* ---- state ---- */
  var root = null, data = null, lastSig = null, statusMsg = null;

  function tone(pct) { return pct >= 90 ? 'bad' : pct >= 80 ? 'warn' : ''; }

  /* card header with its own refresh button (re-runs the feed probe) */
  function head(title, label) {
    return '<h3><span>' + title + '</span><button type="button" class="ghost sys-btn" ' +
      'data-act="refresh">' + (label || 'refresh') + '</button></h3>';
  }

  /* ---- card renderers (each returns card html; callers esc() feed strings) ---- */
  function cardUpdates(d) {
    var u = d.updates;
    if (!u) return '';
    var cls = u.count === 0 ? 'ok' : u.count > 20 ? 'bad' : 'warn';
    var body = u.count === 0
      ? '<div class="sys-sub">system up to date</div>'
      : '<details class="sys-pkgs"><summary>' + u.count + ' package' +
        (u.count === 1 ? '' : 's') + ' pending</summary><ul class="sys-list">' +
        (u.packages || []).map(function (p) { return '<li><code>' + esc(p) + '</code></li>'; }).join('') +
        '</ul></details>';
    return '<div class="sys-card c4">' + head('Updates', 'check updates') +
      '<div class="sys-big ' + cls + '">' + u.count + '</div>' + body +
      '<div class="sys-hint">pacman -Qu — upgrades stay a governed rung</div></div>';
  }

  function cardUnits(d) {
    var un = d.units;
    if (!un) return '';
    var user = un.user_failed || [];
    var sys = un.system_failed || [];
    var failed = user.concat(sys);
    var cls = failed.length ? 'bad' : 'ok';
    var body = user.length
      ? '<ul class="sys-list">' + user.map(function (n) {
          return '<li><code>' + esc(n) + '</code>' +
            '<button type="button" class="ghost sys-btn" data-act="reset" data-unit="' +
            esc(n) + '">reset failed</button></li>';
        }).join('') + '</ul>' : '';
    body += sys.length
      ? '<ul class="sys-list"><li><code>' + sys.map(esc).join('</code> <code>') +
        '</code><span class="sys-hint">system scope — no reset here</span></li></ul>' : '';
    body += failed.length ? '' : '<div class="sys-sub">no failed units</div>';
    body += '<div class="sys-row"><input type="text" class="sys-unit-input" ' +
      'id="sys-unit-input" placeholder="unit (e.g. hngh-cadence-day.timer)" ' +
      'autocomplete="off" spellcheck="false"></div>' +
      '<div class="sys-row"><button type="button" class="ghost sys-btn" ' +
      'data-act="svc" data-verb="start">start</button> ' +
      '<button type="button" class="ghost sys-btn" data-act="svc" ' +
      'data-verb="stop">stop</button> ' +
      '<button type="button" class="ghost sys-btn" data-act="svc" ' +
      'data-verb="restart">restart</button></div>' +
      '<div class="sys-hint">allowlisted units only — timer stop pauses ' +
      'cadence; service-ctl.sh is the single gated path</div>';
    return '<div class="sys-card c4">' + head('Failed units') +
      '<div class="sys-big ' + cls + '">' + failed.length + '</div>' + body +
      '<div class="sys-sub">' + (un.user_running != null ? un.user_running + ' user services running' : '') +
      '</div></div>';
  }

  function cardDisk(d) {
    if (!d.disk) return '';
    var bars = d.disk.map(function (m) {
      return '<div class="sys-row"><span><b>' + esc(m.mount) + '</b> ' +
        esc(m.size) + '</span><span>' + m.use_pct + '% · ' + esc(m.avail) + ' free</span></div>' +
        '<div class="sys-bar"><div class="sys-fill ' + tone(m.use_pct) +
        '" style="width:' + Math.min(100, m.use_pct) + '%"></div></div>';
    }).join('');
    return '<div class="sys-card c4">' + head('Disk') + bars + '</div>';
  }

  function cardMemory(d) {
    var m = d.memory;
    if (!m) return '';
    var t = tone(Math.round(m.used_pct));
    var pk = m.peak ? ' · peak ' + m.peak.used_gb + ' GB' : '';
    return '<div class="sys-card c2">' + head('Memory') +
      '<div class="sys-big ' + t + '">' + m.used_pct + '%</div>' +
      '<div class="sys-sub">' + m.available_gb + ' GB available' + pk +
      '</div>' +
      '<div class="sys-bar"><div class="sys-fill ' + t +
      '" style="width:' + Math.min(100, m.used_pct) + '%"></div></div></div>';
  }

  function cardJournal(d) {
    if (d.journal_err_24h == null) return '';
    var n = d.journal_err_24h;
    var cls = n > 500 ? 'bad' : n > 100 ? 'warn' : 'ok';
    return '<div class="sys-card c2">' + head('Journal errors · 24h') +
      '<div class="sys-big ' + cls + '">' + n + '</div>' +
      '<div class="sys-sub">priority err and worse, user + system</div></div>';
  }

  function cardPackages(d) {
    var p = d.packages;
    if (!p) return '';
    var o = p.orphans != null ? p.orphans : null;
    return '<div class="sys-card c2">' + head('Packages') +
      '<div class="sys-big ' + (o > 0 ? 'warn' : 'ok') + '">' + (o == null ? '—' : o) +
      '</div><div class="sys-sub">orphans</div>' +
      '<div class="sys-row"><span>explicit</span><b>' + (p.explicit != null ? p.explicit : '—') + '</b></div>' +
      '<div class="sys-row"><span>foreign / AUR</span><b>' + (p.foreign_aur != null ? p.foreign_aur : '—') + '</b></div></div>';
  }

  function cardTemps(d) {
    if (!d.temps) return '';
    var rows = d.temps.map(function (t) {
      var cls = t.C >= 90 ? 'bad' : t.C >= 80 ? 'warn' : '';
      return '<div class="sys-temp"><span>' + esc(t.label) + '</span><b class="' + cls +
        '" style="color:var(--' + (cls === 'bad' ? 'danger' : cls === 'warn' ? 'warn' : 'ink') + ')">' +
        t.C.toFixed(1) + '°C</b></div>';
    }).join('');
    return '<div class="sys-card c4">' + head('Temperatures') + rows + '</div>';
  }

  function cardNetwork(d) {
    var n = d.network;
    if (!n) return '';
    return '<div class="sys-card c2">' + head('Network') +
      '<div class="sys-row"><span>local ip</span><b><code>' + esc(n.ip || '—') + '</code></b></div>' +
      '<div class="sys-big">' + (n.listening != null ? n.listening : '—') + '</div>' +
      '<div class="sys-sub">tcp ports listening</div></div>';
  }

  function cardSessions(d) {
    var s = d.sessions;
    if (!s) return '';
    return '<div class="sys-card c4">' + head('Connected sessions') +
      '<div class="sys-big ' + (s.live > 0 ? 'ok' : '') + '">' + s.live + '</div>' +
      '<div class="sys-sub">live of ' + s.total + ' omp/bridge sessions</div></div>';
  }

  function cardBackups(d) {
    var rows = d.backups || [];
    var list = rows.length
      ? '<ul class="sys-list">' + rows.map(function (b) {
          return '<li><span class="sys-tag ' + (b.ok ? 'ok' : 'bad') + '">' +
            (b.ok ? 'ok' : esc(b.kind || 'fail')) + '</span>' +
            '<span>' + esc(String(b.text).replace(/^config-backup\s+/, '')) +
            ' · ' + ago(b.ts) + '</span></li>';
        }).join('') + '</ul>'
      : '<div class="sys-sub">no config-backup runs in the ledger yet</div>';
    return '<div class="sys-card c8">' + head('Config backups') +
      '<button type="button" class="ghost sys-btn" data-act="backup" ' +
      'style="margin:0 0 6px;display:inline-block">run backup now</button>' + list +
      '<div class="sys-hint">jobs/config-backup.sh agent-configs — validate, scan, commit, push</div></div>';
  }

  /* card registry: [renderer] — span class lives in the card div */
  var CARDS = [cardUpdates, cardUnits, cardMemory, cardNetwork, cardDisk,
               cardPackages, cardJournal, cardSessions, cardTemps, cardBackups];

  /* ---- rendering ---- */
  function render() {
    if (!data || !root) return;
    root.innerHTML =
      '<p class="sys-note">feed @ ' + ago(data.generated) +
      (statusMsg ? ' · <span class="sys-status">' + esc(statusMsg) + '</span>' : '') + '</p>' +
      '<div class="sys-cards">' + CARDS.map(function (c) { return c(data); }).join('') + '</div>' +
      '<p class="sys-foot">safe ops only — feed re-probe, failed-state reset (user scope), ' +
      'allowlisted unit start/stop/restart (timer stop pauses cadence), and the ' +
      'config-backup lane; every action is handoffs-logged. package upgrades ' +
      '(pacman -Syu) and other mutations are a future governed rung.' +
      ((data.notes && data.notes.length)
        ? ' feed notes: ' + data.notes.map(esc).join(' · ') : '') + '</p>';
  }

  function applyData(force) {
    if (!data) return;
    var raw = JSON.stringify(data);
    var changed = raw !== lastSig;
    lastSig = raw;
    // static grid: geometry is content-fitted, so only re-render when the
    // data actually moved (or on tab activation) — spare the DOM the churn
    if (force || changed) render();
  }

  /* ---- actions ---- */
  function setStatus(msg) { statusMsg = msg; }

  /* re-run the feed probe server-side; resolves with the fresh payload */
  function probe() {
    return post('system/refresh', {}).then(function (r) {
      if (!r.json || !r.json.feed) throw new Error((r.json && r.json.error) || 'HTTP ' + r.status);
      data = r.json.feed;
      lastSig = JSON.stringify(data);
      render();
      return data;
    });
  }

  function onRefresh(btn) {
    var orig = btn.textContent;
    btn.disabled = true;
    btn.textContent = 'refreshing…';
    probe().then(function () {
      setStatus('feed re-probed');
    }).catch(function (e) {
      setStatus('refresh failed: ' + e.message);
      btn.disabled = false;
      btn.textContent = orig;
    });
  }

  function onReset(btn) {
    var unit = btn.getAttribute('data-unit');
    btn.disabled = true;
    post('system/reset-failed', { unit: unit }, 20000).then(function (r) {
      if (r.json && r.json.ok) setStatus('reset-failed ' + unit + ' — ok');
      else setStatus('reset-failed ' + unit + ' failed: ' + ((r.json && r.json.error) || 'rc ' + (r.json && r.json.rc)));
      return probe();
    }).catch(function (e) {
      setStatus('reset-failed ' + unit + ' failed: ' + e.message);
      btn.disabled = false;
    });
  }

  function onBackup(btn) {
    btn.disabled = true;
    btn.textContent = 'running…';
    setStatus('config-backup agent-configs running (validate + scan + commit + push)…');
    render();
    post('system/backup-now', {}, 320000).then(function (r) {
      var j = r.json || {};
      setStatus('backup rc=' + j.rc + ' wall=' + j.wall + 's — ' +
        (j.tail || (j.ok ? 'ok' : 'refused')));
      return probe();
    }).catch(function (e) {
      setStatus('backup failed: ' + e.message);
      btn.disabled = false;
      btn.textContent = 'run backup now';
    });
  }

  function onService(btn) {
    var input = document.getElementById('sys-unit-input');
    var unit = input ? input.value.trim() : '';
    var verb = btn.getAttribute('data-verb');
    if (!unit) { setStatus('service act: enter a unit name first'); return; }
    if (!window.confirm(verb + ' ' + unit + '?')) return;
    btn.disabled = true;
    setStatus('service-act ' + verb + ' ' + unit + ' — running…');
    post('system/service-act', { unit: unit, verb: verb }, 130000).then(function (r) {
      var j = r.json || {};
      if (j.ok) setStatus('service-act ' + verb + ' ' + unit + ' — ok');
      else setStatus('service-act ' + verb + ' ' + unit + ' failed: ' +
        (j.error || ('rc ' + j.rc)));
      return probe();
    }).catch(function (e) {
      setStatus('service-act ' + verb + ' ' + unit + ' failed: ' + e.message);
      btn.disabled = false;
    });
  }

  /* delegated clicks survive every re-render */
  function onClick(e) {
    var btn = e.target.closest ? e.target.closest('[data-act]') : null;
    if (!btn || btn.disabled) return;
    var act = btn.getAttribute('data-act');
    if (act === 'refresh') onRefresh(btn);
    else if (act === 'reset') onReset(btn);
    else if (act === 'svc') onService(btn);
    else if (act === 'backup') onBackup(btn);
  }

  function fail(e) {
    if (root) root.innerHTML = '<p class="sys-err">system feed error: ' +
      esc(e.message) + ' — is hngh-dashboard.service up?</p>';
  }

  function refresh() {
    if (!root) {
      // app.js's mountModule pairing may lag the script load: bootstrap
      // ourselves into the contract root rather than stay unmounted.
      var r = document.getElementById('system-root');
      if (r) { init(r); return; }
    }
    return fetchJson('system-ops.json').then(function (d) {
      data = d;
      applyData(true); // force: refresh() is also the tab-activation hook
    }).catch(fail);
  }

  function init(el) {
    if (root && root.dataset.sysInit === '1') { refresh(); return; } // idempotent
    root = el;
    root.dataset.sysInit = '1';
    root.addEventListener('click', onClick);
    var style = document.createElement('style');
    style.id = 'hngh-system-style';
    style.textContent = STYLE;
    document.head.appendChild(style);
    try { localStorage.removeItem('hngh-system-grid'); } catch (e) { /* storage off */ }
    refresh();
    window.HnghPoll.start(refresh, { interval: POLL_MS });
  }

  window.SystemView = { init: init, refresh: refresh };
})();
