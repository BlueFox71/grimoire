// Analyse des pages Booknode (fonctions pures sur un Document).
// Utilisé par export.js dans l'onglet Booknode de Jules, et testé sous Node.

const MONTHS = {
  janvier: 1, fevrier: 2, février: 2, mars: 3, avril: 4, mai: 5, juin: 6, juillet: 7,
  aout: 8, août: 8, septembre: 9, octobre: 10, novembre: 11, decembre: 12, décembre: 12,
};

const text = (el) => (el ? el.textContent.replace(/\s+/g, ' ').trim() : '');
const digits = (s) => parseInt(String(s).replace(/[^\d]/g, ''), 10) || 0;
const pad = (n) => String(n).padStart(2, '0');

/** « 19 décembre 2025 » → « 2025-12-19 » (null si illisible). */
export function frenchDate(s) {
  const m = String(s).trim().toLowerCase().match(/^(\d{1,2})(?:er)?\s+([a-zéû]+)\s+(\d{4})$/);
  if (!m || !MONTHS[m[2]]) return null;
  return `${m[3]}-${pad(MONTHS[m[2]])}-${pad(parseInt(m[1], 10))}`;
}

/** Identifiant Booknode (chiffres finaux de l'URL d'une fiche). */
export function booknodeIdFromUrl(url) {
  const m = String(url).split('?')[0].match(/^https?:\/\/booknode\.com\/[a-z0-9_]+_(\d{6,})$/);
  return m ? m[1] : null;
}

/** Page « biblio-table » : lignes de livres + nombre total de résultats. */
export function parseLibraryPage(doc) {
  const rows = [];
  for (const item of doc.querySelectorAll('.book-item')) {
    const link = item.querySelector('.book-name a') || item.querySelector('a.cover-thumbnail');
    const url = link ? link.getAttribute('href').split('?')[0] : null;
    const booknodeId = url ? booknodeIdFromUrl(url) : null;
    if (!booknodeId) continue;
    const img = item.querySelector('.book-cover img');
    const thumb = img ? img.getAttribute('data-src') || img.getAttribute('src') : null;
    rows.push({
      booknodeId,
      url,
      title: text(item.querySelector('.book-name')),
      authors: [...item.querySelectorAll('.author-name a')].map(text).filter(Boolean),
      addedAt: frenchDate(text(item.querySelector('.date-added .momentjs-format'))),
      thumbUrl: thumb ? thumb.split('?')[0] : null,
    });
  }
  let total = rows.length;
  for (const el of doc.querySelectorAll('div, span, p')) {
    const m = text(el).match(/^(\d[\d\s]*) résultats?$/);
    if (m && el.children.length === 0) {
      total = digits(m[1]);
      break;
    }
  }
  return { rows, total };
}

/** Fiche livre : couverture, résumé, série, tome, type (via JSON-LD schema.org/Book). */
export function parseBookPage(doc) {
  let book = null;
  for (const s of doc.querySelectorAll('script[type="application/ld+json"]')) {
    try {
      const j = JSON.parse(s.textContent);
      const found = [].concat(j['@graph'] || j).find((x) => x && x['@type'] === 'Book');
      if (found) {
        book = found;
        break;
      }
    } catch (_) {
      /* bloc JSON-LD illisible : on passe au suivant */
    }
  }
  const h1 = doc.querySelector('h1');
  const typeEl = h1 ? h1.nextElementSibling : null;
  const series = book && book.isPartOf ? book.isPartOf : null;
  const position = series && series.position != null ? Number(series.position) : null;
  return {
    coverUrl: book && typeof book.image === 'string' ? book.image : null,
    summary: book && book.description ? String(book.description).trim() : null,
    series: series && series.name ? series.name : null,
    volume: Number.isFinite(position) ? position : null,
    type: typeEl ? text(typeEl) : null,
  };
}

/** Page « Thèmes et Tropes » : deux listes {name, up, down}. */
export function parseThemesPage(doc) {
  const out = { themes: [], tropes: [] };
  for (const h2 of doc.querySelectorAll('h2')) {
    const title = text(h2).toLowerCase();
    const key = title === 'thèmes' ? 'themes' : title === 'tropes' ? 'tropes' : null;
    if (!key) continue;
    let section = h2.nextElementSibling;
    while (section && section.tagName !== 'SECTION' && section.tagName !== 'H2') section = section.nextElementSibling;
    if (!section || section.tagName !== 'SECTION') continue;
    for (const controls of section.querySelectorAll('.vote-controls')) {
      const item = controls.parentElement;
      const name = text(item.querySelector('a'));
      if (!name) continue;
      out[key].push({
        name,
        up: digits(text(controls.querySelector('.positive .numeric_score'))),
        down: digits(text(controls.querySelector('.negative .numeric_score'))),
      });
    }
  }
  return out;
}
