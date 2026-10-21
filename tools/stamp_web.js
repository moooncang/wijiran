// After a web export: give the engine files a per-build name so browsers never reuse a cached build, and
// write the build id into the page (window.WIJIRAN_BUILD) for the in-game version line.
//   node tools/stamp_web.js <build-id> docs/play [docs/mobile ...]
const fs = require('fs'), path = require('path');
const build = process.argv[2];
const dirs = process.argv.slice(3);
if (!build || dirs.length === 0) { console.error('usage: node tools/stamp_web.js <build-id> <dir>...'); process.exit(1); }
for (const dir of dirs) {
  const html = path.join(dir, 'index.html');
  let s = fs.readFileSync(html, 'utf8');
  // the previous stamped name (index.<hash>) or the plain export name (index)
  const m = s.match(/"executable":"(index(?:\.[0-9a-f]+)?)"/);
  if (!m) { console.error('no executable in ' + html); process.exit(1); }
  const old = m[1], fresh = 'index.' + build;
  if (old === fresh) { console.log(dir + ': already ' + fresh); continue; }
  for (const suffix of ['.js', '.wasm', '.pck', '.audio.worklet.js', '.audio.position.worklet.js']) {
    const from = path.join(dir, old + suffix), to = path.join(dir, fresh + suffix);
    if (fs.existsSync(from)) fs.renameSync(from, to);
  }
  s = s.split('"' + old + '.pck"').join('"' + fresh + '.pck"').split('"' + old + '.wasm"').join('"' + fresh + '.wasm"');
  s = s.replace('"executable":"' + old + '"', '"executable":"' + fresh + '"');
  s = s.replace('src="' + old + '.js"', 'src="' + fresh + '.js"');
  if (!s.includes('WIJIRAN_BUILD')) s = s.replace('<script src="', '<script>window.WIJIRAN_BUILD="' + build + '";</script>\n\t\t<script src="');
  else s = s.replace(/window\.WIJIRAN_BUILD="[^"]*"/, 'window.WIJIRAN_BUILD="' + build + '"');
  fs.writeFileSync(html, s);
  console.log(dir + ': ' + old + ' -> ' + fresh);
}
