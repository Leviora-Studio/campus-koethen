import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';

const root = path.resolve(__dirname, '../../..');
const workspace = readFileSync(path.join(root, 'pnpm-workspace.yaml'), 'utf8');
const patches = [...workspace.matchAll(/^\s+[^#\n]+:\s+(patches\/[^\s]+\.patch)$/gm)].map(
  (match) => match[1]!,
);

for (const component of ['backend', 'cms']) {
  test(`${component} dependency image includes every configured package patch before installation`, () => {
    assert.ok(patches.length > 0, 'The check must discover the workspace patch configuration.');
    const dockerfile = readFileSync(path.join(root, `apps/${component}/Dockerfile`), 'utf8');
    const beforeInstall = dockerfile.split(/^RUN pnpm install/m)[0]!;
    const copies = [...beforeInstall.matchAll(/^COPY\s+(\S+)\s+(\S+)\s*$/gm)];
    for (const patch of patches) {
      assert.ok(existsSync(path.join(root, patch)), `Configured patch does not exist: ${patch}`);
      assert.ok(
        copies.some(
          ([, source, destination]) =>
            (source === patch && destination === 'patches/') ||
            (source === 'patches/' && destination === 'patches/') ||
            (source === '.' && destination === '.'),
        ),
        `Missing ${patch} in ${component}'s dependency build context`,
      );
    }
  });
}
