/* desk-view - the installation desk (2026-09-27). Mounted by desk.html.
   Newspaper idiom (broadsheet-view pattern): every string passes esc()
   or textContent; the dateline is the feed's own stamp, never a client
   Date; refresh ONLY via the poll chain (raw timer loops are
   test-banned); an unreachable feed shows #deskerr, never a fabricated
   state. Fail closed: the run button stays disabled with a printed
   reason until approval + armed wicket + clone + manifest all hold, and
   a 409 prints its remediation block verbatim. */
(function () {
  'use strict';
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;',
               '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function showErr(msg) {
    var b = $('deskerr');
    if (!b) return;
    b.hidden = false;
    b.textContent = 'the desk is stalled: ' + msg;
  }

  // ---------- bounded fetches (broadsheet-view pattern) ----------
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
  // postDesk returns {status, body} instead of throwing on !ok: the desk
  // must render 409 remediation / 502 tails, not just an error string.
  function postDesk(url, body, ms) {
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
    var m = document.querySelector('meta[name="hngh-token"]');
    return m ? (m.getAttribute('content') || '') : '';
  }

  // ---------- state cards ----------
  function card(title, big, note, ok) {
    return '<div class="card ' + (ok ? 'ok' : 'bad') + '">' +
      '<h3>' + esc(title) + '</h3>' +
      '<div class="big">' + esc(big) + '</div>' +
      (note ? '<div class="note">' + esc(note) + '</div>' : '') +
      '</div>';
  }

  function stateCards(st) {
    var c = st.clone || {}, m = st.manifest || {}, w = st.wicket || {};
    var installed = (m.pkgs || []).filter(function (p) {
      return p.installed; }).length;
    var total = (m.pkgs || []).length;
    var html = '';
    html += card('upstream clone',
      c.present ? ('present · ' + (c.ref || 'no ref')) : 'absent',
      c.present ? '' : 'omarchy upstream not found (OMARCHY_UPSTREAM_DIR)',
      !!c.present);
    html += card('manifest',
      m.present ? (total + ' installable · ' + m.aur_count + ' aur') : 'absent',
      m.present ? (installed + ' of ' + total + ' installed') :
        'automation/config/omarchy-base.packages missing',
      !!m.present);
    html += card('wicket', w.armed ? 'armed' : 'not armed',
      w.armed ? '' : (w.reason || 'run the bootstrap block'),
      !!w.armed);
    html += card('pins drift', st.drift ? (st.drift.ok ? 'clean' :
      (st.drift.count + ' drifted')) : 'no drift feed',
      st.drift ? '' : 'jobs/pins-drift.py unavailable',
      st.drift ? !!st.drift.ok : true);
    var approved = !!(st.approvals && st.approvals['desk-authz:phase-1']);
    html += card('authorization', approved ? 'approved' : 'not approved',
      approved ? 'desk-authz:phase-1 in the approved ledger' :
        'stage + approve desk-authz:phase-1',
      approved);
    $('state-cards').innerHTML = html;
    $('desk-ready').hidden = !st.phase1_ready;
    $('phase-row-1').querySelector('.phase-status').textContent =
      st.phase1_ready ? 'landed — every session package installed' :
        'actionable — blocked at the gate (see state + actions)';
    $('phase-row-1').querySelector('.phase-status').className =
      'phase-status ' + (st.phase1_ready ? 'ready' : 'blocked');
  }

  // ---------- buttons: printed outcome text, disabled-with-reason ----------
  function runGate(st) {
    // Fail-closed order mirrors the server's 409 chain: approval, armed,
    // clone+manifest. phase1_ready is the OUTCOME, never a gate.
    if (!(st.approvals && st.approvals['desk-authz:phase-1']))
      return 'disabled: stage authorization, then approve' +
        ' desk-authz:phase-1';
    if (!(st.wicket && st.wicket.armed))
      return 'disabled: wicket not armed — ' +
        ((st.wicket && st.wicket.reason) || 'run the bootstrap block');
    if (!(st.clone && st.clone.present))
      return 'disabled: upstream clone missing';
    if (!(st.manifest && st.manifest.present))
      return 'disabled: omarchy-base.packages manifest missing';
    return '';
  }

  // ---------- AUR add-ons: one Run button per aur-marked package ----------
  function aurGate(st) {
    // Mirrors the server's run-aur 409 chain: approval, armed, in-flight.
    if (!(st.approvals && st.approvals['desk-authz:phase-1']))
      return 'disabled: stage authorization, then approve' +
        ' desk-authz:phase-1';
    if (!(st.wicket && st.wicket.armed))
      return 'disabled: wicket not armed — ' +
        ((st.wicket && st.wicket.reason) || 'run the bootstrap block');
    if (st.aur && st.aur.running)
      return 'disabled: an aur build is already in flight';
    return '';
  }

  var aurBuilt = '';  // pkg-set the rows were last built from
  function renderAur(st) {
    var box = $('aur-rows');
    if (!box) return;
    var pkgs = (st.aur && st.aur.pkgs) || [];
    var key = pkgs.join(',');
    if (key !== aurBuilt) {
      aurBuilt = key;
      box.innerHTML = pkgs.map(function (p) {
        return '<div class="choice-row">' +
          '<button id="aur-run-' + esc(p) + '" class="choice">Run ' +
          esc(p) + '</button>' +
          '<span class="outcome" id="aur-out-' + esc(p) + '">builds in' +
          ' the user session (jobs/aur-build.sh), stages via the' +
          ' wicket; the printed install-file command is the follow-up' +
          '</span></div>' +
          '<div id="aur-reason-' + esc(p) + '" class="reason" hidden>' +
          '</div>';
      }).join('');
      pkgs.forEach(function (p) {
        $('aur-run-' + p).addEventListener('click', function () {
          runAur(p);
        });
      });
    }
    var gate = aurGate(st);
    pkgs.forEach(function (p) {
      var b = $('aur-run-' + p);
      if (!b) return;
      b.disabled = !!gate;
      var rr = $('aur-reason-' + p);
      rr.hidden = !gate;
      rr.textContent = gate;
    });
  }

  function runAur(p) {
    var b = $('aur-run-' + p);
    b.disabled = true;
    out('aur-out-' + p, 'building ' + p + '… (up to 900s)');
    $('remediation').hidden = true;
    postDesk('/desk/run-aur', { pkg: p }).then(function (r) {
      if (r.status === 201) {
        out('aur-out-' + p, 'staged ' + (r.body.pkg || p) +
          ' — tail' + (r.body.follow_up ? ' + follow-up command' : '') +
          ' printed below');
        $('remediation').hidden = false;
        $('remediation').textContent =
          (r.body.tail || '(no output)') +
          (r.body.follow_up ? '\n' + r.body.follow_up : '');
      } else if (r.status === 409) {
        b.disabled = false;
        out('aur-out-' + p, 'refused: ' + (r.body.error || ''));
        $('remediation').hidden = false;
        $('remediation').textContent = r.body.remediation ||
          '(no remediation printed)';
      } else if (r.status === 502) {
        b.disabled = false;
        out('aur-out-' + p, 'failed rc ' + r.body.rc + ' — tail:');
        $('remediation').hidden = false;
        $('remediation').textContent = r.body.tail || '(no output)';
      } else {
        b.disabled = false;
        out('aur-out-' + p, 'refused (' + r.status + '): ' +
          (r.body.error || 'unknown'));
      }
      poll();
    }).catch(function (e) {
      b.disabled = false;
      out('aur-out-' + p, 'failed: ' + e.message);
    });
  }

  function render(st) {
    if (!st || typeof st !== 'object') throw new Error('bad state feed');
    stateCards(st);
    var gate = runGate(st);
    $('btn-run').disabled = !!gate;
    var rr = $('run-reason');
    rr.hidden = !gate;
    rr.textContent = gate;
    var approved = !!(st.approvals && st.approvals['desk-authz:phase-1']);
    $('btn-stage').disabled = approved;
    var sr = $('stage-reason');
    sr.hidden = !approved;
    sr.textContent = approved ? 'disabled: already approved —' +
      ' desk-authz:phase-1 is in the approved ledger' : '';
    renderAur(st);
    $('desk-line').textContent = 'the installation desk · state stamped '
      + (st.generated || '(unstamped)');
  }

  function poll() {
    return fetchJSON('/desk-state.json').then(render).catch(function (e) {
      showErr(e.message);
    });
  }
  function chain() {
    // poll chain only — raw interval loops are test-banned
    setTimeout(function () { poll(); chain(); }, 30000);
  }

  function out(id, text) {
    $(id).textContent = text;
  }

  $('btn-stage').addEventListener('click', function () {
    var b = $('btn-stage');
    b.disabled = true;
    out('stage-outcome', 'filing…');
    postDesk('/desk/stage-authz', { phase: '1' }).then(function (r) {
      if (r.status === 201) {
        out('stage-outcome', 'filed: ' + (r.body.identity || '') +
          ' — run the bootstrap block printed below, then approve the' +
          ' item');
        $('remediation').hidden = false;
        $('remediation').textContent = r.body.remediation ||
          '(bootstrap block missing from the response — see the' +
          ' desk-authz:phase-1 item in the newspaper operator feed)';
        poll();
      } else {
        b.disabled = false;
        out('stage-outcome', 'refused (' + r.status + '): ' +
          (r.body.error || 'unknown'));
        if (r.body.remediation) {
          $('remediation').hidden = false;
          $('remediation').textContent = r.body.remediation;
        }
      }
    }).catch(function (e) {
      b.disabled = false;
      out('stage-outcome', 'failed: ' + e.message);
    });
  });

  $('btn-run').addEventListener('click', function () {
    var b = $('btn-run');
    b.disabled = true;
    out('run-outcome', 'running the privileged install… (up to 900s)');
    $('remediation').hidden = true;
    postDesk('/desk/run-phase-1', {}).then(function (r) {
      if (r.status === 201) {
        out('run-outcome', 'rc ' + r.body.rc + ' — landed. tail:');
        $('remediation').hidden = false;
        $('remediation').textContent = r.body.tail || '(no output)';
      } else if (r.status === 409) {
        b.disabled = false;
        out('run-outcome', 'refused: ' + (r.body.error || ''));
        $('remediation').hidden = false;
        $('remediation').textContent = r.body.remediation ||
          '(no remediation printed)';
      } else {
        b.disabled = false;
        out('run-outcome', 'failed rc ' + r.body.rc + ' — tail:');
        $('remediation').hidden = false;
        $('remediation').textContent = r.body.tail || '(no output)';
      }
      poll();
    }).catch(function (e) {
      b.disabled = false;
      out('run-outcome', 'failed: ' + e.message);
    });
  });

  poll();
  chain();
})();
