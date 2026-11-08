import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DOMParser } from 'linkedom';
import { parseLibraryPage, parseBookPage, parseThemesPage, frenchDate, booknodeIdFromUrl } from './parse.js';

const load = (name) =>
  new DOMParser().parseFromString(readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8'), 'text/html');

test('frenchDate converts long french dates', () => {
  assert.equal(frenchDate('19 décembre 2025'), '2025-12-19');
  assert.equal(frenchDate('1 mars 2024'), '2024-03-01');
  assert.equal(frenchDate('22 janvier 2022'), '2022-01-22');
  assert.equal(frenchDate('1er août 2020'), '2020-08-01');
  assert.equal(frenchDate('n’importe quoi'), null);
  // Dans le HTML brut (avant moment.js), la date est au format AAAA-MM-JJ HH:MM:SS.
  assert.equal(frenchDate('\n   2022-01-22 21:19:42\n  '), '2022-01-22');
});

test('booknodeIdFromUrl extracts the trailing digits', () => {
  assert.equal(booknodeIdFromUrl('https://booknode.com/fourth_wing_03477053'), '03477053');
  assert.equal(booknodeIdFromUrl('https://booknode.com/la_mort_du_roi_tsongor_0695'), '0695');
  assert.equal(booknodeIdFromUrl('https://booknode.com/auteur/x'), null);
  assert.equal(booknodeIdFromUrl('https://booknode.com/serie/the-empyrean'), null);
});

test('parseLibraryPage reads rows and total', () => {
  const { rows, total, skipped } = parseLibraryPage(load('library.html'));
  assert.equal(total, 679);
  assert.equal(skipped, 0);
  assert.equal(rows.length, 3);
  assert.deepEqual(rows[0], {
    booknodeId: '02702795',
    url: 'https://booknode.com/blyd_pearce_02702795',
    title: 'Blyd & Pearce',
    authors: ['Kim Fielding'],
    addedAt: '2022-01-22',
    thumbUrl: 'https://cdn1.booknode.com/book_cover/1150/mod11/blyd_pearce-1149937-121-198.webp',
  });
  assert.equal(rows[1].thumbUrl, 'https://cdn1.booknode.com/book_cover/2000/mod11/baker-street-121-198.webp');
  assert.deepEqual(rows[2].authors, ['Autrice Une', 'Auteur Deux']);
  assert.equal(rows[2].thumbUrl, null);
  assert.equal(rows[2].addedAt, '2025-12-19');
});

test('parseBookPage reads cover, summary, series and type', () => {
  const d = parseBookPage(load('book.html'));
  assert.equal(d.coverUrl, 'https://cdn1.booknode.com/book_cover/5806/full/fourth-wing-5805999.jpg');
  assert.match(d.summary, /^Rien ne prédestinait Violet Sorrengail/);
  assert.equal(d.series, 'The Empyrean');
  assert.equal(d.volume, 1);
  assert.equal(d.type, 'Livre');
});

test('parseThemesPage separates themes and tropes with votes', () => {
  const { themes, tropes } = parseThemesPage(load('themes.html'));
  assert.deepEqual(themes[0], { name: 'Dragons', up: 171, down: 1 });
  assert.deepEqual(themes[1], { name: 'Young Adult', up: 27, down: 16 });
  assert.deepEqual(themes[2], { name: 'Fantasy épique', up: 1042, down: 4 });
  assert.equal(themes.length, 3);
  assert.deepEqual(tropes, [{ name: 'Ennemis à amants (Enemies to lovers)', up: 41, down: 6 }]);
});

test('parseThemesPage on a page without sections returns empty lists', () => {
  const { themes, tropes } = parseThemesPage(load('book.html'));
  assert.deepEqual(themes, []);
  assert.deepEqual(tropes, []);
});

test('parseLibraryPage counts items it could not read', () => {
  const html = readFileSync(new URL('./fixtures/library.html', import.meta.url), 'utf8').replaceAll(
    'https://booknode.com/blyd_pearce_02702795',
    'https://booknode.com/livre-bizarre',
  );
  const { rows, skipped } = parseLibraryPage(new DOMParser().parseFromString(html, 'text/html'));
  assert.equal(rows.length, 2);
  assert.equal(skipped, 1);
});
