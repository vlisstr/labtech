
function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function htmlDoc(title, body) {
  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>${escapeHtml(title)}</title></head>
<body>
${body}
</body>
</html>
`;
}

function renderTable(headers, rows) {
  const headHtml = headers.map((h) => `<th>${escapeHtml(h)}</th>`).join('');
  const rowsHtml = rows
    .map(
      (row) =>
        `<tr>${row.map((cell) => `<td>${escapeHtml(cell)}</td>`).join('')}</tr>`
    )
    .join('\n');
  return `<table border="1">
<thead><tr>${headHtml}</tr></thead>
<tbody>
${rowsHtml}
</tbody>
</table>`;
}

module.exports = { escapeHtml, htmlDoc, renderTable };
