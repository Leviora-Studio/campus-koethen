/**
 * Makes the prismjs core available to the built admin panel.
 *
 * ## Why this exists
 *
 * `@strapi/content-manager` ships the Blocks editor's code block, and Vite
 * bundles prismjs LANGUAGE definitions into the admin build. Those are plain
 * scripts calling `Prism.languages.extend(...)` on a BARE GLOBAL, but the
 * prismjs core is never attached to `window`.
 *
 * The failure mode is deceptive: the admin serves a COMPLETELY BLANK page while
 * every asset returns HTTP 200 and the server log stays clean. The only
 * evidence is `Uncaught ReferenceError: Prism is not defined` in the browser
 * console.
 *
 * Upstream bug, not a defect of this repository:
 * https://github.com/strapi/strapi/issues/25070
 *
 * ## Three earlier attempts that genuinely did not work
 *
 *  1. `src/admin/app.tsx`, the workaround documented upstream. The
 *     content-manager chunk is evaluated BEFORE the user config module, so it
 *     throws before the assignment runs. Verified: `window.Prism` was still
 *     undefined after the crash.
 *  2. A Vite plugin using `transformIndexHtml`. Strapi renders the admin HTML
 *     itself instead of passing it through Vite, so the hook never fires.
 *     Verified: the marker attribute was absent from the built HTML.
 *  3. Injecting the core INLINE into the HTML head. Strapi's security
 *     middleware sets `script-src 'self'`, so the browser silently refuses to
 *     execute an inline script. Verified: the tag was in the DOM, the content
 *     evaluated fine by hand, and it had simply never run.
 *
 * ## What this does instead
 *
 * Emits the core as a SEPARATE file next to the other admin assets and
 * references it with a normal `<script src>`. Same-origin, so it satisfies
 * `script-src 'self'` without weakening the policy — the CSP is worth keeping.
 * A classic, non-deferred script in `<head>` also runs before any module chunk,
 * which is the ordering the language files require.
 *
 * Remove this once the upstream fix ships, and verify by loading /admin in a
 * real browser: a successful build proves nothing, the failure is at runtime.
 */

import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));

const MARKER = 'data-campus-shim="prismjs-core"';

const buildDir = join(here, '..', 'dist', 'build');
const indexPath = join(buildDir, 'index.html');

let html;
try {
  html = readFileSync(indexPath, 'utf8');
} catch {
  console.error(`[prism-shim] ${indexPath} not found. Run this after "strapi build".`);
  process.exit(1);
}

// The FULL default bundle, not `components/prism-core.min.js`. The core alone
// registers only plain/plaintext/text/txt, and the bundled language files
// extend `Prism.languages.clike` and friends — with core-only that fails with
// "Cannot set properties of undefined (setting 'comment')", which is just the
// blank page again with a different message. prism.js ships core plus markup,
// css, clike and javascript, which is what those files expect to build on.
const core = readFileSync(require.resolve('prismjs/prism.js'), 'utf8');

// Content-hashed filename, like every other admin asset. Without it a browser
// keeps executing a previously cached copy under the same name, which produced
// exactly the failure it was meant to fix and looked like the shim not working.
const digest = createHash('sha256').update(core).digest('hex').slice(0, 8);
const assetName = `campus-prism-${digest}.js`;
writeFileSync(join(buildDir, assetName), core, 'utf8');

if (html.includes(MARKER)) {
  console.log(`[prism-shim] HTML already references a shim; leaving it untouched`);
  process.exit(0);
}

// The admin is served under /admin, alongside its other assets.
// data-manual stops Prism from auto-highlighting the document on load: the
// admin manages its own code blocks and does not want a global sweep.
const tag = `<script ${MARKER} data-manual src="/admin/${assetName}"></script>`;
const injected = html.replace('<head>', `<head>${tag}`);

if (injected === html) {
  console.error('[prism-shim] no <head> found in the built admin HTML; aborting');
  process.exit(1);
}

writeFileSync(indexPath, injected, 'utf8');
console.log(
  `[prism-shim] wrote ${assetName} (${core.length} bytes) and referenced it from index.html`,
);
