// Directory listing helper (Lua can't list folders, Node can).
// Called from server.lua via exports[resource]:listMetas(absPath)
const fs = require('fs');
const path = require('path');

// 'stream' only holds models/textures (never vehicle metas) and is the biggest folder in most packs
const SKIP = new Set(['node_modules', '.git', 'stream']);

function walk(dir, base, out) {
  let entries;
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return; }
  for (const e of entries) {
    const full = path.join(dir, e.name);
    let isDir = e.isDirectory();
    if (e.isSymbolicLink()) { try { isDir = fs.statSync(full).isDirectory(); } catch (_) { continue; } }
    if (isDir) {
      if (!SKIP.has(e.name)) walk(full, base, out);
    } else if (e.name.toLowerCase().endsWith('.meta')) {
      out.push(path.relative(base, full).split(path.sep).join('/'));
    }
  }
}

exports('listMetas', (absPath) => {
  const out = [];
  walk(absPath, absPath, out);
  return out;
});
