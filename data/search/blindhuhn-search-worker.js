/*
 * Blindhuhn search worker.
 *
 * This is a `SharedWorker` that fetches the raw JSON search index, builds
 * fuzzy finders (for names and modules; using fzf), and answers to search
 * queries from pages that embed `blindhuhn-search.js`.
 */
import { Fzf } from "./fzf.es.js";

const INDEX_URL = "index.json";

let entries = [];
let fzfNames = null;
let fzfModules = null;

// Bypass the browser cache to fetch an up-to-date search index. Some servers
// might not send the correct cache-control headers (looking at you, Python
// http module), so this forces a fresh load. Performance impact is negligible
// since the worker is loaded only once per session.
const ready = fetch(INDEX_URL, { cache: "no-store" })
  .then((res) => {
    if (!res.ok) {
      throw new Error("blindhuhn: failed to load " + INDEX_URL);
    }
    return res.json();
  })
  .then((data) => {
    entries = data.definitions || [];

    const modules = [...new Set(entries.map((e) => e.module))];

    fzfNames = new Fzf(entries, { selector: (e) => e.name });
    fzfModules = new Fzf(modules);
  });

// Parses a query into a module part and an name part, split on the last '.':
//  - "foo"     -> module-only: modules matching "foo", all their names.
//  - ".foo"    -> name-only: "foo" across all modules.
//  - "bar.foo" -> modules matching "bar", names matching "foo" in them.
function parseQuery(needle) {
  const dotIndex = needle.lastIndexOf(".");
  if (dotIndex === -1) {
    return { moduleQuery: needle || undefined, nameQuery: undefined };
  }
  return {
    moduleQuery: needle.slice(0, dotIndex) || undefined,
    nameQuery: needle.slice(dotIndex + 1) || undefined,
  };
}

function findModules(query) {
  if (!query) {
    return undefined;
  }
  return new Set(fzfModules.find(query).map((r) => r.item));
}

function findNames(query) {
  if (!query) {
    return entries;
  }
  return fzfNames.find(query).map((r) => r.item);
}

async function search(needle) {
  await ready;

  const { moduleQuery, nameQuery } = parseQuery(needle);
  const nameResults = findNames(nameQuery);
  const moduleResults = findModules(moduleQuery);

  const results = moduleResults
    ? nameResults.filter((e) => moduleResults.has(e.module))
    : nameResults;

  const publicResults = results.filter((e) => e.visibility === "public");

  return publicResults.slice(0, 50);
}

self.onconnect = function (event) {
  const port = event.ports[0];

  port.onmessage = function (ev) {
    const { requestId, query } = ev.data;
    const trimmed = (query || "").trim();

    if (trimmed === "") {
      port.postMessage({ requestId, results: [] });
      return;
    }

    search(trimmed)
      .then((results) => port.postMessage({ requestId, results }))
      .catch(() => port.postMessage({ requestId, results: [] }));
  };

  port.start();
};
