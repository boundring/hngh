/* wizard-view - the Winamp-skinned install wizard (2026-10-06).
   Mounted by wizard.html. desk-view idiom: every string passes esc()
   or textContent; the state line is the feed's own stamp, never a
   client Date; refresh ONLY via the poll chain (raw timer loops are
   test-banned); an unreachable feed shows #wizerr, never a fabricated
   state. Fail closed: privileged buttons stay disabled with a printed
   reason until the seed params hold, GO-REAL stays dark until the
   FORMATTED checkbox is ticked, and a 409 prints its remediation
   block verbatim. */
(function () {
  'use strict';
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;',
               '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function out(id, text) {
    var el = $(id);
    if (el) el.textContent = text;
  }

  function showErr(msg) {
    var b = $('wizerr');
    if (!b) return;
    b.hidden = false;
    b.textContent = msg;
  }

  // 409 remediation renders verbatim; 502 tails and 400 errors too.
  function renderRefusal(r) {
    var body = (r && r.body) || {};
    if (body.remediation) { showErr(body.remediation); return; }
    if (body.tail) { showErr(body.tail); return; }
    showErr('refused (' + (r ? r.status : '?') + '): ' +
      (body.error || 'unknown'));
  }

  // ---------- bounded fetches (desk-view pattern) ----------
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
    return fetchText(url, ms).then(function (s) { return JSON.parse(s); });
  }

  // postWizard returns {status, body} instead of throwing on !ok: the
  // wizard must render 409 remediation / 502 tails verbatim, not just
  // an error string.
  function postWizard(url, body, ms) {
    var ctrl = new AbortController();
    var t = setTimeout(function () { ctrl.abort(); }, ms || 900000);
    return fetch(url, {
      method: 'POST', cache: 'no-store', signal: ctrl.signal,
      headers: { 'Content-Type': 'application/json',
                 'X-Hngh-Token': hnghToken() },
      body: JSON.stringify(body || {})
    }).then(function (r) {
      clearTimeout(t);
      return r.json().catch(function () { return {}; })
        .then(function (j) { return { status: r.status, body: j }; });
    }).catch(function (e) { clearTimeout(t); throw e; });
  }

  // token plumbing (app.js / broadsheet-view pattern)
  function hnghToken() {
    // the served page carries two token metas (server-injected real one
    // first, then the empty placeholder): take the first NON-EMPTY
    // content across all matches, else ''
    var metas = document.querySelectorAll('meta[name="hngh-token"]');
    for (var i = 0; i < metas.length; i++) {
      var v = metas[i].getAttribute('content') || '';
      if (v) return v;
    }
    return '';
  }

  // ---------- small helpers ----------
  var touched = {};      // per-input: operator typed here, never stomp
  var entryPreview = ''; // last entry block the server rendered
  var lastState = null;  // last rendered feed, for checkbox re-gates
  var isoKey = '';       // key of the last rendered candidate set
  var diskKey = '';      // key of the last rendered disk list
  var authKey = '';      // key of the last rendered key-file list

  function splitList(v) {
    return String(v == null ? '' : v).split(/[,\n]+/)
      .map(function (s) { return s.trim(); })
      .filter(function (s) { return s !== ''; });
  }

  function humanSize(n) {
    n = Number(n) || 0;
    var units = ['B', 'KB', 'MB', 'GB', 'TB'], i = 0;
    while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
    return (i ? n.toFixed(1) : String(Math.round(n))) + ' ' + units[i];
  }

  function mtimeText(m) {
    // formats the state's own epoch stamp; never a client Date
    var d = new Date((Number(m) || 0) * 1000);
    if (isNaN(d.getTime())) return String(m == null ? '' : m);
    return d.toISOString().slice(0, 16).replace('T', ' ');
  }

  function isRefusal(tail) {
    return /refus|fail-closed|denied/i.test(String(tail || ''));
  }

  // ---------- LCD log readouts ----------
  function setLog(id, tail) {
    var pre = $(id);
    if (!pre) return;
    // only follow the tail when the operator was already at the bottom
    var atBottom = pre.scrollHeight - pre.scrollTop - pre.clientHeight < 8;
    pre.textContent = tail || '(no output)';
    pre.className = 'log' + (isRefusal(tail) ? ' err' : '');
    if (atBottom) pre.scrollTop = pre.scrollHeight;
  }

  function setBadge(id, cls, text) {
    var b = $(id);
    if (!b) return;
    b.className = 'badge ' + cls;
    b.textContent = text || cls;
  }

  // ---------- steps rail: badges derive from the feed only ----------
  function renderSteps(st) {
    var steps = st.steps || {};
    var logs = st.logs || {};
    function tailOf(k) { return (logs[k] && logs[k].tail) || ''; }
    function runBadge(k) { // running / refused / done / pending
      if (steps[k] && steps[k].running) return 'running';
      var t = tailOf(k);
      if (!t) return 'pending';
      return isRefusal(t) ? 'refused' : 'done';
    }
    setBadge('step-iso', st.iso ? 'done' :
      (steps.download && steps.download.running ? 'running' : 'pending'));
    setBadge('step-seed', (st.seed && st.seed.cidata) ? 'done' : 'pending');
    setBadge('step-pilot', runBadge('pilot'));
    // the verdict is verify's own outcome: only BOOTED+SSH counts done
    var v = st.verdict;
    setBadge('step-verify', (steps.verify && steps.verify.running) ?
      'running' : (v === 'BOOTED+SSH' ? 'done' : (v ? 'refused' : 'pending')));
    setBadge('step-go-real', runBadge('go-real'));
    setBadge('step-entry', st.entry ? 'done' : 'pending');
    setBadge('step-done',
      (st.entry && v === 'BOOTED+SSH') ? 'done' : 'pending');
  }

  // ---------- ISO pane ----------
  function renderIso(st) {
    out('iso-selected', st.iso || 'none');
    var list = st.isos || [];
    var key = JSON.stringify(list.map(function (x) { return x.path; }));
    if (key === isoKey) return;
    isoKey = key;
    var box = $('iso-list');
    if (!list.length) {
      box.innerHTML = '<div class="placeholder">' +
        esc('no ISO candidates in the scan directories') + '</div>';
      return;
    }
    box.innerHTML = list.map(function (x, i) {
      return '<div class="iso-row">' +
        '<span class="iso-name">' + esc(x.name || x.path) + '</span>' +
        '<span class="iso-meta">' + esc(humanSize(x.size)) + '</span>' +
        '<span class="iso-meta">' + esc(mtimeText(x.mtime)) + '</span>' +
        '<button type="button" class="pick" id="iso-pick-' + i +
        '">Select</button></div>' +
        '<div class="iso-path">' + esc(x.path) + '</div>';
    }).join('');
    list.forEach(function (x, i) {
      var b = $('iso-pick-' + i);
      if (b) b.addEventListener('click', function () { selectIso(x.path); });
    });
  }

  function selectIso(path) {
    out('iso-out', 'selecting...');
    postWizard('/wizard/iso-select', { path: path }).then(function (r) {
      if (r.status === 201) {
        out('iso-out', 'selected: ' + (r.body.path || path));
        poll();
      } else {
        out('iso-out', 'refused (' + r.status + ')');
        renderRefusal(r);
      }
    }).catch(function (e) {
      out('iso-out', 'failed: ' + e.message);
    });
  }

  function downloadIso() {
    out('iso-out', 'starting download...');
    postWizard('/wizard/iso-download', { url: $('iso-url').value.trim() })
      .then(function (r) {
        if (r.status === 201) {
          out('iso-out', 'download started (pid ' + (r.body.pid || '?') +
            ') -> ' + (r.body.path || ''));
          poll();
        } else {
          out('iso-out', 'refused (' + r.status + ')');
          renderRefusal(r);
        }
      }).catch(function (e) {
        out('iso-out', 'failed: ' + e.message);
      });
  }

  // ---------- options pane: prefill only untouched inputs ----------
  function prefill(id, val) {
    if (touched[id]) return;
    var el = $(id);
    if (el) el.value = val == null ? '' : val;
  }

  function renderOptions(st) {
    var p = (st.seed && st.seed.params) || {};
    prefill('opt-user', p.user);
    prefill('opt-disk', p.disk);
    prefill('opt-packages', (p.packages || []).join(', '));
    prefill('opt-repos', (p.repos || []).join(', '));
    prefill('opt-services', (p.services || []).join(', '));
    prefill('opt-authkey', p.authkey_path);
    if (!touched['opt-defer'])
      $('opt-defer').checked = p.defer !== false;
    out('authkey-current', p.authkey_path || 'none');
  }

  function renderAuthkeys(st) {
    // candidate key FILES only (paths from the state, names never
    // contents); clicking a line fills the authkey path input
    var files = st.authkey_files || [];
    var key = JSON.stringify(files);
    if (key === authKey) return;
    authKey = key;
    var box = $('authkey-list');
    if (!files.length) {
      box.innerHTML = '<div class="placeholder">' +
        esc('no key files reported under the secrets home') + '</div>';
      return;
    }
    box.innerHTML = files.map(function (f, i) {
      return '<button type="button" class="auth-row" id="auth-key-' + i +
        '">' + esc(f) + '</button>';
    }).join('');
    files.forEach(function (f, i) {
      var b = $('auth-key-' + i);
      if (b) b.addEventListener('click', function () {
        $('opt-authkey').value = f;
        touched['opt-authkey'] = true;
      });
    });
  }

  function renderDisks(st) {
    var ds = st.disks || [];
    var key = JSON.stringify(ds);
    if (key === diskKey) return;
    diskKey = key;
    var box = $('disk-list');
    if (!ds.length) {
      box.innerHTML = '<div class="placeholder">' +
        esc('no disks reported by the driver') + '</div>';
      return;
    }
    box.innerHTML = ds.map(function (d) {
      return '<div class="disk-row">' +
        '<span class="d-name">' + esc(d.name) + '</span>' +
        '<span class="iso-meta">' + esc(d.size) + '</span>' +
        '<span class="iso-meta">' + esc(d.fstype || '-') + '</span>' +
        '<span class="iso-meta">' + esc(d.partuuid || '-') + '</span>' +
        '<span class="iso-meta">' + esc(d.mountpoints ||
          (d.unmounted ? 'unmounted' : '-')) + '</span></div>';
    }).join('');
  }

  function seedParams() {
    return {
      user: $('opt-user').value.trim(),
      disk: $('opt-disk').value.trim(),
      packages: splitList($('opt-packages').value),
      repos: splitList($('opt-repos').value),
      services: splitList($('opt-services').value),
      authkey_path: $('opt-authkey').value.trim(),
      defer: $('opt-defer').checked
    };
  }

  function runSeed() {
    out('seed-out', 'seeding...');
    postWizard('/wizard/seed', seedParams()).then(function (r) {
      if (r.status === 201) {
        out('seed-out', 'seed ok (rc ' +
          (r.body.rc == null ? '?' : r.body.rc) +
          ') - tail in the SEED readout');
        setLog('log-seed', r.body.tail);
        poll();
      } else {
        out('seed-out', 'refused (' + r.status + ')');
        if (r.body && r.body.tail) setLog('log-seed', r.body.tail);
        renderRefusal(r);
      }
    }).catch(function (e) {
      out('seed-out', 'failed: ' + e.message);
    });
  }

  // ---------- privileged steps: disabled-with-reason, feed only ----------
  function gateFor(st, name) {
    var steps = st.steps || {};
    var p = (st.seed && st.seed.params) || {};
    if (steps[name] && steps[name].running)
      return 'disabled: ' + name + ' is running (pid ' +
        (steps[name].pid == null ? '?' : steps[name].pid) + ')';
    var busy = '';
    ['pilot', 'verify', 'go-real'].forEach(function (s) {
      if (s !== name && steps[s] && steps[s].running) busy = s;
    });
    if (busy)
      return 'disabled: another privileged step is running: ' + busy;
    if (!p.user)
      return 'disabled: no seed user - fill SEED OPTIONS and press SEED';
    if (!p.disk)
      return 'disabled: no target disk in the seed params';
    return '';
  }

  function renderGates(st) {
    [['pilot', 'btn-pilot'], ['verify', 'btn-verify'],
     ['go-real', 'btn-go-real']].forEach(function (pair) {
      var name = pair[0], b = $(pair[1]);
      if (!b) return;
      var g = gateFor(st, name);
      if (name === 'go-real' && !g && !$('go-real-check').checked)
        g = 'disabled: tick the FORMATTED checkbox to arm GO-REAL';
      b.disabled = !!g;
      var rr = $(name + '-reason');
      if (rr) { rr.hidden = !g; rr.textContent = g; }
    });
  }

  function runStep(name) {
    // the FORMATTED checkbox is the only way GO-REAL opens a terminal
    if (name === 'go-real' && !$('go-real-check').checked) return;
    out('steps-out', 'opening a terminal for ' + name + '...');
    postWizard('/wizard/terminal', { step: name }).then(function (r) {
      if (r.status === 201) {
        out('steps-out', 'terminal opened (pid ' + (r.body.pid || '?') +
          '): ' + (r.body.cmd || name));
        poll();
      } else {
        out('steps-out', 'refused (' + r.status + ')');
        renderRefusal(r);
      }
    }).catch(function (e) {
      out('steps-out', 'failed: ' + e.message);
    });
  }

  function runEntry() {
    out('entry-out', 'rendering entry preview...');
    postWizard('/wizard/entry-preview', {}).then(function (r) {
      if (r.status === 201) {
        entryPreview = r.body.entry || '';
        $('entry-block').textContent = entryPreview ||
          '(the server returned no entry text)';
        out('entry-out', 'entry block rendered');
        poll();
      } else {
        out('entry-out', 'refused (' + r.status + ')');
        renderRefusal(r);
      }
    }).catch(function (e) {
      out('entry-out', 'failed: ' + e.message);
    });
  }

  function render(st) {
    if (!st || typeof st !== 'object') throw new Error('bad state feed');
    lastState = st;
    out('wiz-line', 'wizard state stamped ' +
      (st.generated || '(unstamped)'));
    renderSteps(st);
    renderIso(st);
    renderOptions(st);
    renderAuthkeys(st);
    renderDisks(st);
    renderGates(st);
    var logs = st.logs || {};
    setLog('log-seed', logs.seed && logs.seed.tail);
    setLog('log-pilot', logs.pilot && logs.pilot.tail);
    setLog('log-verify', logs.verify && logs.verify.tail);
    setLog('log-go-real', logs['go-real'] && logs['go-real'].tail);
    setLog('log-download', logs.download && logs.download.tail);
    $('entry-block').textContent = st.entry || entryPreview ||
      '(no entry block yet - press ENTRY PREVIEW)';
    out('formatted-warning', 'DANGER: ' +
      ((st.seed && st.seed.params && st.seed.params.disk) ||
       'THE SELECTED DISK') + ' WILL BE FORMATTED - EVERY BYTE ON IT ' +
      'WILL BE LOST');
  }

  function poll() {
    return fetchJSON('/wizard-state.json').then(render).catch(function (e) {
      showErr('the wizard feed is unreachable: ' + e.message);
    });
  }
  function chain() {
    // poll chain only - raw interval loops are test-banned
    setTimeout(function () { poll(); chain(); }, 30000);
  }

  // ---------- panes: drag by title bar, resize by corner grip ----------
  // transform-based drag keeps panes in normal flow, so the page still
  // works when pointer events are missing (no pinning, no reflow).
  var zTop = 5;
  function startMove(e, pane) {
    if (e.button !== 0) return;
    var sx = e.clientX, sy = e.clientY;
    var dx = pane._dx || 0, dy = pane._dy || 0;
    pane.style.zIndex = String(++zTop);
    function mv(ev) {
      pane._dx = dx + ev.clientX - sx;
      pane._dy = dy + ev.clientY - sy;
      pane.style.transform =
        'translate(' + pane._dx + 'px,' + pane._dy + 'px)';
    }
    function up() {
      window.removeEventListener('pointermove', mv);
      window.removeEventListener('pointerup', up);
    }
    window.addEventListener('pointermove', mv);
    window.addEventListener('pointerup', up);
    e.preventDefault();
  }

  function startResize(e, pane) {
    if (e.button !== 0) return;
    var sx = e.clientX, sy = e.clientY;
    var w0 = pane.offsetWidth, h0 = pane.offsetHeight;
    function mv(ev) {
      pane.style.width = Math.max(260, w0 + ev.clientX - sx) + 'px';
      pane.style.height = Math.max(120, h0 + ev.clientY - sy) + 'px';
    }
    function up() {
      window.removeEventListener('pointermove', mv);
      window.removeEventListener('pointerup', up);
    }
    window.addEventListener('pointermove', mv);
    window.addEventListener('pointerup', up);
    e.preventDefault();
  }

  function movable(pane) {
    if (!window.PointerEvent) return; // panes still work in plain flow
    var bar = pane.querySelector('.titlebar');
    var grip = pane.querySelector('.grip');
    if (bar) bar.addEventListener('pointerdown', function (e) {
      startMove(e, pane);
    });
    if (grip) grip.addEventListener('pointerdown', function (e) {
      startResize(e, pane);
    });
  }

  // ---------- wiring ----------
  ['opt-user', 'opt-disk', 'opt-packages', 'opt-repos', 'opt-services',
   'opt-authkey'].forEach(function (id) {
    var el = $(id);
    if (el) el.addEventListener('input', function () { touched[id] = true; });
  });
  $('opt-defer').addEventListener('change', function () {
    touched['opt-defer'] = true;
  });
  $('go-real-check').addEventListener('change', function () {
    if (lastState) renderGates(lastState);
  });
  $('btn-iso-download').addEventListener('click', downloadIso);
  $('btn-seed').addEventListener('click', runSeed);
  $('btn-pilot').addEventListener('click', function () { runStep('pilot'); });
  $('btn-verify').addEventListener('click', function () { runStep('verify'); });
  $('btn-go-real').addEventListener('click', function () {
    runStep('go-real');
  });
  $('btn-entry').addEventListener('click', runEntry);
  Array.prototype.forEach.call(
    document.querySelectorAll('.pane'), movable);

  poll();
  chain();
})();
