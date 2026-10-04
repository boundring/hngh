/* control-room map — the hngh megastructure with live states.
   docs/design/megastructure-sim.md P1: seed topology hosts, live fleet
   nodes on the ground ring, alert fauna orbiting the automation ring,
   ring tint follows the open-item count. Positions are editorial, not
   measured; unknown names stay 'unresolved'. */
function $(id) { return document.getElementById(id); }
function esc(s) {
  return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
  });
}
var MAP_SEEDS = [
  { id: 'operator-host', label: 'operator host', layer: 2, x: 0, z: 0 },
  { id: 'kernel-core', label: 'kernel core', layer: 1, x: 0, z: 0 },
  { id: 'automation', label: 'automation ring', layer: 0, x: 2.6, z: 0.4 },
  { id: 'cadence-hour', label: 'cadence: hour', layer: 0, x: -1.8, z: 2.2 },
  { id: 'cadence-subhour', label: 'cadence: subhour', layer: 0, x: -2.4, z: -1.6 },
  { id: 'cadence-calendar', label: 'cadence: calendar', layer: 0, x: 1.2, z: -2.8 },
  { id: 'userspace-home', label: 'userspace home', layer: -1, x: 0.6, z: 3.2 },
  { id: 'remote-origin', label: 'remote origin', layer: -1, x: -3.4, z: 0.8 }
];
var MAP_EDGES = [
  ['operator-host', 'kernel-core'], ['kernel-core', 'automation'],
  ['kernel-core', 'cadence-hour'], ['kernel-core', 'cadence-subhour'],
  ['kernel-core', 'cadence-calendar'], ['kernel-core', 'userspace-home'],
  ['automation', 'remote-origin']
];
var mapState = { scene: null, cam: null, rend: null, raf: 0,
                 dist: 9, theta: 0.6, phi: 1.15, drag: null, lastWheel: 0,
                 live: null, ring: null, fauna: null, THREE: null };
function mapLabel(THREE, text, color) {
  var c = document.createElement('canvas');
  c.width = 256; c.height = 64;
  var g = c.getContext('2d');
  g.fillStyle = 'rgba(244,240,230,0.75)';
  g.fillRect(0, 0, 256, 64);
  g.font = 'bold 26px sans-serif';
  g.fillStyle = color || '#26221c';
  g.textAlign = 'center'; g.textBaseline = 'middle';
  g.fillText(text.slice(0, 22), 128, 32);
  var spr = new THREE.Sprite(new THREE.SpriteMaterial({ map: new THREE.CanvasTexture(c) }));
  spr.scale.set(1.7, 0.42, 1);
  return spr;
}
function mapNodeDot(THREE, color) {
  return new THREE.Mesh(new THREE.SphereGeometry(0.13, 12, 10),
    new THREE.MeshLambertMaterial({ color: color }));
}
function mapInit(fleetNodes, openCount) {
  var host = $('map3d');
  if (!host) return;
  if (mapState.built) { mapRefresh(fleetNodes, openCount); return; }
  mapState.built = true;
  import('./vendor/three.module.min.js').then(function (THREE) {
    try { mapBuild(THREE, host); mapRefresh(fleetNodes, openCount); }
    catch (e) { mapFallback(fleetNodes, openCount, e.message); }
  }).catch(function (e) { mapFallback(fleetNodes, openCount, e.message); });
}
function mapBuild(THREE, host) {
  var w = host.clientWidth, h = host.clientHeight;
  var rend = new THREE.WebGLRenderer({ antialias: true });
  if (!rend.getContext()) throw new Error('map webgl unavailable');
  rend.setSize(w, h);
  rend.setPixelRatio(Math.min(devicePixelRatio || 1, 1.6));
  host.appendChild(rend.domElement);
  mapState.rend = rend;
  var scene = new THREE.Scene();
  scene.background = new THREE.Color(0x191b1f);
  scene.add(new THREE.AmbientLight(0xffffff, 0.75));
  var sun = new THREE.DirectionalLight(0xfff4e0, 0.9);
  sun.position.set(4, 6, 3);
  scene.add(sun);
  mapState.THREE = THREE;
  var byId = {};
  MAP_SEEDS.forEach(function (s) {
    var y = 0.4 + s.layer * 1.15;
    var isRing = s.id === 'automation';
    var dot = mapNodeDot(THREE, isRing ? 0x4a6b3a : 0x26221c);
    dot.position.set(s.x, y, s.z);
    var lab = mapLabel(THREE, s.label);
    lab.position.set(s.x, y + 0.34, s.z);
    scene.add(dot); scene.add(lab);
    byId[s.id] = [s.x, y, s.z];
    if (isRing) mapState.ring = dot.material;
  });
  MAP_EDGES.forEach(function (e) {
    var a = byId[e[0]], b = byId[e[1]];
    if (!a || !b) return;
    var g = new THREE.BufferGeometry().setFromPoints(
      [new THREE.Vector3(a[0], a[1], a[2]),
       new THREE.Vector3(b[0], b[1], b[2])]);
    scene.add(new THREE.Line(g,
      new THREE.LineBasicMaterial({ color: 0x8a8070 })));
  });
  mapState.live = new THREE.Group();
  scene.add(mapState.live);
  mapState.scene = scene; mapState.cam = cam0(THREE, w, h);
  mapBindInput(host);
  mapResize();
  if (window.ResizeObserver)
    mapState.ro = new ResizeObserver(mapResize).observe(host);
  if (!mapState.raf) mapState.raf = requestAnimationFrame(mapFrame);
}
function cam0(THREE, w, h) {
  var cam = new THREE.PerspectiveCamera(46, w / Math.max(1, h), 0.1, 100);
  return cam;
}
function mapRefresh(fleetNodes, openCount) {
  var s = mapState;
  if (!s.live || !s.THREE) return;
  var THREE = s.THREE;
  s.scene.remove(s.live);
  s.live = new THREE.Group();
  s.scene.add(s.live);
  // LIVE fleet nodes on a lower ground ring; green = online.
  (fleetNodes || []).forEach(function (n, i) {
    var ang = (i / Math.max(1, fleetNodes.length)) * Math.PI * 2;
    var x = Math.cos(ang) * 4.4, z = Math.sin(ang) * 4.4;
    var named = n.name && n.name !== '?';
    var dot = mapNodeDot(THREE, n.online ? 0x4a6b3a : 0x8a4a3a);
    dot.position.set(x, -0.6, z);
    var lab = mapLabel(THREE, named ? n.name : 'unresolved',
      n.online ? '#35502a' : '#7a4030');
    lab.position.set(x, -0.25, z);
    s.live.add(dot); s.live.add(lab);
    var g = new THREE.BufferGeometry().setFromPoints(
      [new THREE.Vector3(0, 0.4, 0), new THREE.Vector3(x, -0.6, z)]);
    s.live.add(new THREE.Line(g,
      new THREE.LineBasicMaterial({ color: 0xb9b09c })));
  });
  // ALERT FAUNA: one red mote per open item, capped so a flood reads as
  // a swarm, not as geometry (docs/design/megastructure-sim.md fauna).
  s.fauna = new THREE.Group();
  var cap = Math.min(openCount || 0, 8);
  for (var i = 0; i < cap; i++) {
    var mote = mapNodeDot(THREE, 0x8a3a2e);
    mote.scale.set(0.55, 0.55, 0.55);
    var ang = (i / Math.max(1, cap)) * Math.PI * 2;
    mote.position.set(2.6 + Math.cos(ang) * 0.7, 1.05,
                      0.4 + Math.sin(ang) * 0.7);
    s.fauna.add(mote);
  }
  if (cap < (openCount || 0)) {
    var more = mapLabel(THREE, '+' + (openCount - cap) + ' more', '#7a4030');
    more.position.set(2.6, 1.5, 0.4);
    s.fauna.add(more);
  }
  s.live.add(s.fauna);
  // RING TINT follows attention: green when quiet, amber when items open.
  if (s.ring) s.ring.color.setHex(openCount > 0 ? 0x8a6b2a : 0x4a6b3a);
}
function mapBindInput(host) {
  host.addEventListener('pointerdown', function (ev) {
    mapState.drag = { x: ev.clientX, y: ev.clientY };
  });
  addEventListener('pointerup', function () { mapState.drag = null; });
  addEventListener('pointermove', function (ev) {
    if (!mapState.drag) return;
    mapState.theta -= (ev.clientX - mapState.drag.x) * 0.005;
    mapState.phi = Math.min(2.6, Math.max(0.5,
      mapState.phi - (ev.clientY - mapState.drag.y) * 0.005));
    mapState.drag = { x: ev.clientX, y: ev.clientY };
  });
  host.addEventListener('wheel', function (ev) {
    ev.preventDefault();
    var now = Date.now();
    if (now - mapState.lastWheel < 120) return; // throttle zoom
    mapState.lastWheel = now;
    mapState.dist = Math.min(22, Math.max(4,
      mapState.dist + (ev.deltaY > 0 ? 0.7 : -0.7)));
  }, { passive: false });
  addEventListener('resize', mapResize);
}
function mapResize() {
  var s = mapState; if (!s.rend || !s.cam) return;
  var host = $('map3d'); if (!host) return;
  s.rend.setSize(host.clientWidth, host.clientHeight);
  s.cam.aspect = host.clientWidth / Math.max(1, host.clientHeight);
  s.cam.updateProjectionMatrix();
}
function prefs() {
  var d = { attentionCap: 8, rotate: true, pollMs: 30000 };
  try {
    var raw = localStorage.getItem('control-room-prefs');
    if (!raw) return d;
    var v = JSON.parse(raw) || {};
    return { attentionCap: [4, 8, 12, 16].indexOf(v.attentionCap) >= 0 ? v.attentionCap : d.attentionCap,
             rotate: v.rotate !== false,
             pollMs: [15000, 30000, 60000].indexOf(v.pollMs) >= 0 ? v.pollMs : d.pollMs };
  } catch (e) { return d; }
}

function savePrefs(next) {
  try { localStorage.setItem('control-room-prefs', JSON.stringify(next)); } catch (e) { /* private mode */ }
}

function wireSettings() {
  var btn = document.getElementById('settings-btn');
  var box = document.getElementById('settings');
  if (!btn || !box) return;
  btn.addEventListener('click', function () { box.hidden = !box.hidden; });
  var p = prefs();
  var att = document.getElementById('set-attention');
  var rot = document.getElementById('set-rotate');
  var pol = document.getElementById('set-poll');
  if (att) { att.value = String(p.attentionCap); att.addEventListener('change', applySettings); }
  if (rot) { rot.checked = p.rotate; rot.addEventListener('change', applySettings); }
  if (pol) { pol.value = String(p.pollMs / 1000); pol.addEventListener('change', applySettings); }
}

function applySettings() {
  var p = {
    attentionCap: parseInt(document.getElementById('set-attention').value, 10),
    rotate: document.getElementById('set-rotate').checked,
    pollMs: parseInt(document.getElementById('set-poll').value, 10) * 1000
  };
  savePrefs(p);
  renderAttention(lastItems);
}

function mapFrame() {
  mapState.raf = requestAnimationFrame(mapFrame);
  var s = mapState;
  if (!s.scene || document.hidden) return;
  if (prefs().rotate) s.scene.rotation.y += 0.0012; // slow auto-rotation, settings can stop it
  if (s.fauna) s.fauna.rotation.y -= 0.004;
  s.cam.position.set(
    s.dist * Math.sin(s.phi) * Math.cos(s.theta),
    s.dist * Math.cos(s.phi),
    s.dist * Math.sin(s.phi) * Math.sin(s.theta));
  s.cam.lookAt(0, 0, 0);
  s.rend.render(s.scene, s.cam);
}
// honest 2D fallback: a plain list with status dots, real names only
function mapFallback(fleetNodes, openCount, why) {
  var host = $('map3d');
  if (host) host.hidden = true;
  var fb = $('map-fallback');
  if (!fb) return;
  fb.hidden = false;
  var ul = document.createElement('ul');
  MAP_SEEDS.forEach(function (s) {
    var li = document.createElement('li');
    li.innerHTML = '<span class="map-dot on"></span>' + esc(s.label);
    ul.appendChild(li);
  });
  (fleetNodes || []).forEach(function (n) {
    var li = document.createElement('li');
    var named = n.name && n.name !== '?';
    li.innerHTML = '<span class="map-dot ' +
      (n.online ? 'on' : 'off') + '"></span>' +
      esc(named ? n.name : 'mesh node (unresolved)') +
      ' - ' + (n.online ? 'online' : 'offline') +
      (n.os ? ' - ' + esc(n.os) : '');
    ul.appendChild(li);
  });
  var li = document.createElement('li');
  li.innerHTML = '<span class="map-dot off"></span>' +
    esc(openCount || 0) + ' open operator items';
  ul.appendChild(li);
  fb.appendChild(ul);
  if (window.console) console.warn('control-room map fallback: ' + why);
}
function fetchJSON(url) {
  return fetch(url + '?t=' + Date.now()).then(function (r) {
    if (!r.ok) throw new Error(r.status + ' ' + url);
    return r.json();
  });
}
function editionAge(gen, now) {
  var t = Date.parse(gen);
  if (!isFinite(t)) return null;
  var m = Math.max(0, Math.round((now - t) / 60000));
  var text = m >= 60
    ? Math.floor(m / 60) + 'h ' + (m % 60) + 'm old'
    : m + 'm old';
  return { text: text, stale: m >= 90 };
}
var lastItems = [];

function renderAttention(items) {
  lastItems = items || [];
  var ol = $('attention-list');
  if (!ol) return;
  ol.innerHTML = '';
  items.slice(0, prefs().attentionCap).forEach(function (it) {
    var li = document.createElement('li');
    li.innerHTML = '<span class="att-text">' + esc(it.text) + '</span>' +
      (it.first_seen ? '<span class="att-age">' +
        esc(String(it.first_seen).slice(0, 10)) + '</span>' : '');
    ol.appendChild(li);
  });
  var rest = items.length - Math.min(items.length, 8);
  if (rest > 0) {
    var li = document.createElement('li');
    li.innerHTML = '<a href="console.html">' + esc(rest) +
      ' more — the nerve center holds the verbs</a>';
    ol.appendChild(li);
  }
}
function renderDateline(ed, generated, openCount, fleetNodes) {
  var el = $('dateline');
  if (!el) return;
  var sys = (ed && ed.system) || {};
  var age = editionAge(generated, Date.now());
  var online = (fleetNodes || []).filter(function (f) {
    return f && f.online; }).length;
  var bits = [
    (ed && ed.date) || 'undated',
    age ? (age.stale ? 'stale edition · ' + age.text
                     : 'edition ' + age.text) : '',
    'queue ' + (sys.queue_depth != null ? sys.queue_depth : '?') +
      ' - sessions ' + (sys.sessions_active != null
        ? sys.sessions_active : '?') +
      ' - fleet ' + online + '/' + ((fleetNodes || []).length) + ' online',
    (openCount != null ? openCount + ' open' : '')
  ].filter(Boolean);
  el.textContent = bits.join(' · ');
}
function poll() {
  Promise.allSettled([
    fetchJSON('operator-items.json'),
    fetchJSON('fleet.json'),
    fetchJSON('newspaper.json')
  ]).then(function (rs) {
    var o = rs[0].status === 'fulfilled' ? rs[0].value : null;
    var f = rs[1].status === 'fulfilled' ? rs[1].value : null;
    var n = rs[2].status === 'fulfilled' ? rs[2].value : null;
    var items = o && Array.isArray(o.items) ? o.items : [];
    var nodes = f && Array.isArray(f.nodes) ? f.nodes : [];
    renderAttention(items);
    mapInit(nodes, items.length);
    renderDateline(n && n.edition, n && n.generated,
                   items.length, nodes);
  });
}
wireSettings();
pollLoop();

function pollLoop() {
  poll();
  // house poll pattern: setTimeout chain, no raw timer loops
  setTimeout(pollLoop, prefs().pollMs);
}
