/* global marked */
const BUILD = (window.__BUILD__ || 'dev');

const FILELIST_URL = 'filelist.json';
const NAV_EL       = document.getElementById('nav');
const NAV_TOGGLE   = document.getElementById('navToggle');
const CONTENT_EL   = document.getElementById('content');
const TOC_EL       = document.getElementById('toc');
const SEARCH_EL    = document.getElementById('search');
const THEME_TOGGLE = document.getElementById('themeToggle');
const BASE_TITLE = 'Ich bin – und das ist genug';
const LS_LAST  = 'genug:last';
const LS_THEME = 'genug:theme';

// Merkliste aller verfügbaren Markdown-Dateien (für hashchange-Handling)
let MD_FILES = new Set();

/* ---------------- Theme ---------------- */
(function initTheme(){
  const html   = document.documentElement;
  const saved  = localStorage.getItem(LS_THEME);
  const system = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  const initial = (saved === 'light' || saved === 'dark') ? saved : system;
  html.setAttribute('data-theme', initial);

  THEME_TOGGLE?.addEventListener('click', () => {
    const next = html.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    html.setAttribute('data-theme', next);
    localStorage.setItem(LS_THEME, next);
  });

  // Lange drücken = zurück zur System-Automatik
  THEME_TOGGLE?.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    localStorage.removeItem(LS_THEME);
    html.setAttribute(
      'data-theme',
      window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
    );
  });
})();

/* -------------- Mobile Nav Toggle -------------- */
NAV_TOGGLE?.addEventListener('click', () => {
  document.body.classList.toggle('nav-open');
});
// Auf Mobile beim Laden die Navi sichtbar machen
if (window.matchMedia('(max-width: 960px)').matches) {
  document.body.classList.add('nav-open');
}

/* ---------------- Utils ---------------- */
function byPathTree(paths) {
  const root = {};
  for (const p of paths) {
    const parts = p.split('/').filter(Boolean);
    let node = root;
    for (let i=0; i<parts.length; i++){
      const part = parts[i];
      const isLeaf = (i === parts.length - 1);
      if (!node[part]) node[part] = isLeaf ? null : {};
      if (!isLeaf) node = node[part];
    }
  }
  return root;
}
function el(tag, attrs={}, children=[]){
  const e = document.createElement(tag);
  Object.entries(attrs).forEach(([k,v]) => {
    if (k === 'class') e.className = v;
    else if (k === 'html') e.innerHTML = v;
    else e.setAttribute(k, v);
  });
  children.forEach(c => e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c));
  return e;
}
function titleCase(s){ return s.replace(/[-_]/g,' ').replace(/\b\w/g, m=>m.toUpperCase()); }
function niceName(file){
  const base = file.split('/').pop().replace(/\.md$/i,'');
  return titleCase(base);
}
function buildTOC(container){
  const heads = Array.from(container.querySelectorAll('h2, h3'));
  if (!heads.length) { TOC_EL.hidden = true; TOC_EL.innerHTML=''; return; }
  TOC_EL.hidden = false;
  TOC_EL.innerHTML = '';
  heads.forEach(h => {
    if (!h.id) h.id = h.textContent.trim().toLowerCase().replace(/\s+/g,'-').replace(/[^\w\-]/g,'');
    TOC_EL.appendChild(el('a', {href: '#'+h.id}, [h.textContent]));
  });
}
function addHeadingAnchors(container){
  container.querySelectorAll('h2, h3, h4').forEach(h => {
    if (!h.id) h.id = h.textContent.trim().toLowerCase().replace(/\s+/g,'-').replace(/[^\w\-]/g,'');
    h.appendChild(el('a', {href:'#'+h.id, title:'Link kopieren', style:'margin-left:.4rem; opacity:.7;'}, ['🔗']));
  });
}

/* ---------------- Navigation ---------------- */
function buildNav(tree, basePath=''){
  const ul = el('ul', {class:'tree'});
  Object.keys(tree).sort((a,b)=>a.localeCompare(b,'de')).forEach(key => {
    const val = tree[key];
    if (val === null) {
      const full = (basePath ? basePath + '/' : '') + key;
      const li = el('li', {class:'leaf'});
      const a  = el('a', {href:'#'+full}, [niceName(full)]);
      a.dataset.file = full;
      li.appendChild(a);
      ul.appendChild(li);
    } else {
      const li = el('li');
      li.appendChild(el('div', {class:'folder'}, [titleCase(key)]));
      li.appendChild(buildNav(val, (basePath ? basePath + '/' : '') + key));
      ul.appendChild(li);
    }
  });
  return ul;
}
function markActive(file){
  NAV_EL.querySelectorAll('a').forEach(a => {
    a.classList.toggle('active', a.dataset.file === file);
  });
}

async function loadFileList(){
  const res = await fetch(FILELIST_URL);
  const files = await res.json();
  const md = files.filter(f => f.toLowerCase().endsWith('.md'));

  // Merken für hashchange
  MD_FILES = new Set(md);

  const tree = byPathTree(md);
  NAV_EL.innerHTML = '';
  NAV_EL.appendChild(buildNav(tree));

  // Filter
  SEARCH_EL.addEventListener('input', () => {
    const q = SEARCH_EL.value.trim().toLowerCase();
    NAV_EL.querySelectorAll('.leaf').forEach(li => {
      const a = li.querySelector('a');
      const label = a.textContent.toLowerCase();
      const path  = a.dataset.file.toLowerCase();
      li.style.display = (label.includes(q) || path.includes(q)) ? '' : 'none';
    });
  });

  // Clicks
  NAV_EL.addEventListener('click', (e) => {
    const a = e.target.closest('a[data-file]');
    if (!a) return;
    e.preventDefault();
    const file = a.dataset.file;
    if (file) loadMarkdown(file, true);
  });

  // Startwahl: Hash -> LS -> index.md
  const fromHash = decodeURIComponent(location.hash.slice(1));
  const start = md.includes(fromHash) ? fromHash :
                (localStorage.getItem(LS_LAST) && md.includes(localStorage.getItem(LS_LAST))
                  ? localStorage.getItem(LS_LAST) : 'index.md');
  loadMarkdown(start, false);
}

async function loadMarkdown(file, pushHash){
  try{
    const res = await fetch(file);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const text = await res.text();
    let html = marked.parse(text);

    // h1 extrahieren
    const m = html.match(/<h1[^>]*>(.*?)<\/h1>/i);
    const pageTitle = m ? m[1].replace(/<[^>]+>/g,'') : niceName(file);
    if (m) html = html.replace(m[0], '');

    document.title = `${pageTitle} – Ich bin genug · v${BUILD}`;
    CONTENT_EL.innerHTML = `<h1>${pageTitle}</h1>${html}`;

    // Wichtig: erst ToC, dann 🔗-Icons ergänzen (sonst landen die Icons im ToC)
    buildTOC(CONTENT_EL);
    addHeadingAnchors(CONTENT_EL);

    markActive(file);

    if (pushHash) history.replaceState(null, '', '#'+encodeURIComponent(file));
    localStorage.setItem(LS_LAST, file);

    // Mobile UX: nach Auswahl zum Inhalt & Sidebar zu
    if (window.matchMedia('(max-width: 960px)').matches) {
      CONTENT_EL.scrollIntoView({ behavior: 'smooth', block: 'start' });
      document.body.classList.remove('nav-open');
    }

    // Smooth nach oben
    document.scrollingElement?.scrollTo({ top: 0, behavior: 'smooth' });
  } catch(err){
    CONTENT_EL.innerHTML = `<p><strong>Fehler beim Laden:</strong> ${file}<br><small>${String(err)}</small></p>`;
  }
}

/* -------- Hash-Handling: nur für echte Dateien -------- */
window.addEventListener('hashchange', () => {
  const h = decodeURIComponent(location.hash.slice(1));
  if (MD_FILES.has(h)) {
    // Datei wurde per Hash gewählt
    loadMarkdown(h, false);
  }
  // sonst: normaler In-Page-Anchor – bewusst nichts tun
});

window.addEventListener('load', loadFileList);
