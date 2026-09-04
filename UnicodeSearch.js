function parseEntries(raw) {
  try {
    const data = JSON.parse(String(raw || ""));

    return Array.isArray(data) ? data : [];
  } catch (e) {
    return [];
  }
}

function normalizedQuery(query) {
  return String(query || "")
    .trim()
    .toLowerCase();
}

function filterEntries(entries, query, limit) {
  const values = Array.isArray(entries) ? entries : [];
  const needle = normalizedQuery(query);
  let max = limit === undefined || limit === null ? 1000 : Number(limit);

  if (isNaN(max)) max = 1000;
  max = Math.max(0, max);
  if (max === 0) return [];

  const out = [];

  for (let i = 0; i < values.length; i++) {
    const item = values[i];

    if (!item || !item.e) continue;

    if (!needle || String(item.k || "").indexOf(needle) >= 0) {
      out.push(item);
      if (out.length >= max) break;
    }
  }

  return out;
}

if (typeof module !== "undefined") {
  module.exports = {
    parseEntries: parseEntries,
    normalizedQuery: normalizedQuery,
    filterEntries: filterEntries,
  };
}
