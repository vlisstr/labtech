const { escapeHtml, htmlDoc, renderTable } = require('../lib/render');

describe('escapeHtml', () => {
  test('escapes ampersands', () => {
    expect(escapeHtml('Tom & Jerry')).toBe('Tom &amp; Jerry');
  });
  test('escapes angle brackets', () => {
    expect(escapeHtml('<script>')).toBe('&lt;script&gt;');
  });
  test('escapes double quotes', () => {
    expect(escapeHtml('"hello"')).toBe('&quot;hello&quot;');
  });
  test('escapes single quotes', () => {
    expect(escapeHtml("it's")).toBe('it&#39;s');
  });
  test('stringifies non-strings', () => {
    expect(escapeHtml(42)).toBe('42');
  });
});

describe('htmlDoc', () => {
  test('produces a valid HTML5 doctype', () => {
    const out = htmlDoc('Title', '<p>hello</p>');
    expect(out).toContain('<!DOCTYPE html>');
    expect(out).toContain('<title>Title</title>');
    expect(out).toContain('<p>hello</p>');
  });
  test('escapes the title', () => {
    const out = htmlDoc('<bad>', 'body');
    expect(out).toContain('<title>&lt;bad&gt;</title>');
  });
});

describe('renderTable', () => {
  test('renders header and rows', () => {
    const out = renderTable(['id', 'name'], [[1, 'foo'], [2, 'bar']]);
    expect(out).toContain('<th>id</th>');
    expect(out).toContain('<th>name</th>');
    expect(out).toContain('<td>1</td>');
    expect(out).toContain('<td>foo</td>');
    expect(out).toContain('<td>bar</td>');
  });
  test('escapes cell content', () => {
    const out = renderTable(['x'], [['<script>']]);
    expect(out).toContain('<td>&lt;script&gt;</td>');
    expect(out).not.toContain('<td><script></td>');
  });
});
