import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DOMParser } from 'linkedom';
import { runExport, needsDetails, summarize } from './export.js';

const html = (name) => readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8');
const doc = (s) => new DOMParser().parseFromString(s, 'text/html');
const empty = doc('<html><body><div class="small">0 résultat</div></body></html>');

/** Faux Booknode : la PAL « livre » contient la page library.html, le reste est vide. */
function fakeBooknode(calls) {
  return async (url) => {
    calls.push(url);
    if (url.includes('biblio-table')) {
      return url.includes('media_type=book&list=10&') ? doc(html('library.html').replace('679 résultats', '3 résultats')) : empty;
    }
    if (url.endsWith('/themes')) return doc(html('themes.html'));
    return doc(html('book.html'));
  };
}

test('needsDetails is true for unknown or poorly tagged books', () => {
  assert.equal(needsDetails(undefined), true);
  assert.equal(needsDetails({ details: null }), true);
  assert.equal(needsDetails({ details: { themes: [{ name: 'A', up: 9, down: 0 }], tropes: [] } }), true);
  const full = { details: { themes: [1, 2, 3].map((i) => ({ name: `T${i}`, up: 9, down: 0 })), tropes: [] } };
  assert.equal(needsDetails(full), false);
});

test('runExport builds a complete export from lists, pages and themes', async () => {
  const calls = [];
  const r = await runExport({ user: 'Subarashi', pause: 0, fetchDoc: fakeBooknode(calls) });
  assert.equal(r.format, 'grimoire-booknode-export');
  assert.equal(r.version, 1);
  assert.equal(r.user, 'Subarashi');
  assert.equal(r.complete, true);
  assert.equal(r.books.length, 3);
  const b = r.books[0];
  assert.equal(b.list, 'pal');
  assert.equal(b.type, 'livre');
  assert.equal(b.addedAt, '2022-01-22');
  assert.equal(b.details.series, 'The Empyrean');
  assert.equal(b.details.themes[0].name, 'Dragons');
  assert.equal('thumbUrl' in b, false);
  // 8 listes × 4 types, puis 2 pages par livre ; jamais d'Envies (6) ni de Poubelle (7).
  assert.equal(calls.filter((u) => u.includes('biblio-table')).length, 32);
  assert.equal(calls.filter((u) => /list=(6|7)&/.test(u)).length, 0);
  assert.equal(calls.length, 32 + 6);
  assert.deepEqual(summarize(r).byList, { pal: 3 });
});

test('runExport skips details already known from the previous export', async () => {
  const calls = [];
  const fullDetails = { themes: [1, 2, 3].map((i) => ({ name: `T${i}`, up: 9, down: 0 })), tropes: [] };
  const previous = { books: [{ booknodeId: '02702795', details: fullDetails }] };
  const r = await runExport({ user: 'Subarashi', pause: 0, previous, fetchDoc: fakeBooknode(calls) });
  assert.equal(calls.length, 32 + 4);
  assert.equal(r.books.find((b) => b.booknodeId === '02702795').details, null);
});

test('a failing list page makes the export incomplete', async () => {
  const calls = [];
  const base = fakeBooknode(calls);
  const r = await runExport({
    user: 'Subarashi',
    pause: 0,
    fetchDoc: async (url) => {
      if (url.includes('list=1&')) throw new Error('HTTP 500');
      return base(url);
    },
  });
  assert.equal(r.complete, false);
  assert.ok(globalThis.__grimoireExport.errors.length >= 1);
});
