/* feedback-view — operator feedback pips + capture overlay.

   Adds a small "?" pip beside the tab bar and beside each panel head
   (title "send feedback"); clicking one opens an enlargeable overlay
   (resizable textarea, draggable header) with a free-text area, a type
   selector (css-theme | data-format | correction | idea), an optional
   element/topic line, and Submit. Submission POSTs JSON to
   /api/feedback (write-only; server files one timestamped JSON under
   dashboard/feedback/ for jobs/feedback-ingest.py to standardize into
   the operator-item feed).

   Display layer only — never governance input. All styles live in one
   owned <style> tag (fb- prefix); style.css is not touched. This file
   self-mounts on load (it overlays the whole dashboard, not one tab
   root, so it does not go through app.js MOUNTS — same self-mount
   discipline as app.js's built-in style IIFE). */
(function () {
  'use strict';

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  var TYPES = ['css-theme', 'data-format', 'correction', 'idea'];

  /* ---- pip mounts: tab bar + each visible panel head ---- */
  function makePip(elementTopic) {
    var b = document.createElement('button');
    b.className = 'fb-pip';
    b.type = 'button';
    b.textContent = '?';
    b.title = 'send feedback';
    b.setAttribute('aria-label', 'send feedback about ' + (elementTopic || 'dashboard'));
    b.addEventListener('click', function () {
      openOverlay(elementTopic || '');
    });
    return b;
  }
  function injectPips() {
    var tabs = document.getElementById('tabs');
    // pip mounts on the nav wrapper, never inside the tablist: a
    // role=tablist may own only role=tab children (axe
    // aria-required-children flagged the implicit-button pip).
    if (tabs && tabs.parentNode &&
        !tabs.parentNode.querySelector('.fb-pip'))
      tabs.parentNode.appendChild(makePip('tab bar'));
    document.querySelectorAll('.panel > .panel-head').forEach(function (head) {
      var panel = head.closest('.panel');
      var topic = (head.querySelector('.p-title') || {}).textContent || panel.id;
      if (!head.querySelector('.fb-pip')) head.appendChild(makePip(topic.trim()));
    });
  }

  /* ---- overlay: enlargeable text field + type + element + submit ---- */
  var ov = null;
  function openOverlay(elementTopic) {
    if (ov) { ov.show(elementTopic); return; }
    var st = document.createElement('style');
    st.id = 'fb-style';
    st.textContent =
      '.fb-pip{margin-left:8px;padding:0 5px;line-height:16px;font-size:11px;' +
      'border-radius:50%;border:1px solid var(--line);background:transparent;' +
      'color:var(--muted);cursor:pointer}.fb-pip:hover{color:var(--ink);' +
      'border-color:var(--muted)}' +
      '.fb-ov{position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:99;' +
      'display:flex;align-items:center;justify-content:center}' +
      '.fb-box{background:var(--bg);color:var(--ink);border:1px solid var(--line);' +
      'border-radius:8px;padding:10px;width:420px;max-width:92vw;resize:both;' +
      'overflow:auto;min-width:280px;min-height:200px}' +
      '.fb-head{display:flex;justify-content:space-between;align-items:center;' +
      'cursor:move;font-size:12px;color:var(--muted);margin-bottom:6px}' +
      '.fb-box textarea,.fb-box input{width:100%;box-sizing:border-box;' +
      'background:transparent;color:var(--ink);border:1px solid var(--line);' +
      'border-radius:6px;padding:5px;font:inherit;font-size:12.5px}' +
      '.fb-box textarea{height:130px;resize:vertical;margin:6px 0}' +
      '.fb-row{display:flex;gap:6px;align-items:center;font-size:11.5px;' +
      'color:var(--muted)}.fb-row select{background:var(--bg);color:var(--ink);' +
      'border:1px solid var(--line);border-radius:6px;padding:3px}' +
      '.fb-status{font-size:11px;color:var(--muted);margin-top:5px;min-height:14px}' +
      '.fb-actions{display:flex;gap:6px;justify-content:flex-end;margin-top:6px}';
    document.head.appendChild(st);
    var wrap = document.createElement('div');
    wrap.className = 'fb-ov';
    wrap.innerHTML =
      '<div class="fb-box">' +
      '  <div class="fb-head"><span>send feedback</span><span class="fb-x" style="cursor:pointer">✕</span></div>' +
      '  <div class="fb-row"><span>type</span><select class="fb-type">' +
      TYPES.map(function (t) { return '<option>' + t + '</option>'; }).join('') +
      '  </select><span>element/topic</span><input class="fb-el" maxlength="80"></div>' +
      '  <textarea class="fb-text" maxlength="2000" placeholder="what should change? (plain text)"></textarea>' +
      '  <div class="fb-actions"><button class="ghost fb-send">submit</button></div>' +
      '  <div class="fb-status"></div>' +
      '</div>';
    document.body.appendChild(wrap);
    ov = { wrap: wrap, box: wrap.querySelector('.fb-box') };
    ov.show = show;
    wire(wrap, ov);
    show(elementTopic);
  }
  function show(elementTopic) {
    ov.wrap.style.display = 'flex';
    ov.wrap.querySelector('.fb-el').value = elementTopic || '';
    ov.wrap.querySelector('.fb-status').textContent = '';
    ov.wrap.querySelector('.fb-text').focus();
  }
  function wire(wrap, ov) {
    var box = ov.box;
    wrap.querySelector('.fb-x').addEventListener('click', function () {
      wrap.style.display = 'none';
    });
    wrap.addEventListener('click', function (e) {
      if (e.target === wrap) wrap.style.display = 'none';
    });
    // drag by the header
    var head = wrap.querySelector('.fb-head');
    head.addEventListener('mousedown', function (e) {
      var r = box.getBoundingClientRect(), dx = e.clientX - r.left, dy = e.clientY - r.top;
      box.style.position = 'fixed';
      function mv(e2) {
        box.style.left = (e2.clientX - dx) + 'px';
        box.style.top = (e2.clientY - dy) + 'px';
        box.style.right = 'auto';
      }
      function up() {
        document.removeEventListener('mousemove', mv);
        document.removeEventListener('mouseup', up);
      }
      document.addEventListener('mousemove', mv);
      document.addEventListener('mouseup', up);
    });
    wrap.querySelector('.fb-send').addEventListener('click', submit);
  }
  function submit() {
    var status = ov.wrap.querySelector('.fb-status');
    var payload = {
      type: ov.wrap.querySelector('.fb-type').value,
      text: ov.wrap.querySelector('.fb-text').value.trim(),
      element: ov.wrap.querySelector('.fb-el').value.trim()
    };
    if (!payload.text) { status.textContent = 'nothing to send'; return; }
    status.textContent = 'sending…';
    fetch('/api/feedback', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json',
        'X-Hngh-Token': (window.HnghOps ? window.HnghOps.token() : '') },
      body: JSON.stringify(payload)
    }).then(function (r) {
      if (r.status === 403 && window.HnghOps) window.HnghOps.expired();
      if (r.ok) {
        ov.wrap.querySelector('.fb-text').value = '';
        status.textContent = 'sent — thank you';
        setTimeout(function () { ov.wrap.style.display = 'none'; }, 900);
      } else {
        r.json().then(function (j) {
          status.textContent = 'failed: ' + (j.error || r.status);
        }, function () { status.textContent = 'failed: HTTP ' + r.status; });
      }
    }, function () { status.textContent = 'failed: network'; });
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectPips);
  } else {
    injectPips();
  }
}());
