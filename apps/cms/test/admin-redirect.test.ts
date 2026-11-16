import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { runInNewContext } from 'node:vm';
import ts from 'typescript';
import { safeAdminLoginSearch } from '../src/security/admin-redirect';

test('admin login keeps local content-manager redirects and unrelated query parameters', () => {
  const search = '?redirectTo=%2Fcontent-manager%2Fcollection-types%3Fpage%3D2&demo=1';
  assert.equal(safeAdminLoginSearch(search), search);
  assert.equal(safeAdminLoginSearch(''), '');
});

test('admin login refuses external, backslash, encoded and malformed redirect targets', () => {
  for (const target of [
    '//example.invalid',
    '/\\example.invalid',
    '\\\\example.invalid',
    'https://example.invalid',
    '%2F%5Cexample.invalid',
    '/%5cexample.invalid',
    '/\n/example.invalid',
    '%',
  ]) {
    assert.equal(
      safeAdminLoginSearch(`?redirectTo=${encodeURIComponent(target)}&demo=1`),
      '?demo=1',
      target,
    );
  }
});

test('the admin bootstrap removes unsafe redirects before mounting the login screen', () => {
  const filename = path.resolve(__dirname, '../src/admin/app.tsx');
  const { outputText } = ts.transpileModule(readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX },
  });
  const replacements: string[] = [];
  const exports: { default?: { bootstrap: (app: unknown) => void } } = {};
  runInNewContext(outputText, {
    exports,
    require: createRequire(filename),
    window: {
      location: {
        pathname: '/admin/auth/login',
        search: '?redirectTo=%2F%5Cexample.invalid',
        hash: '',
      },
      history: {
        state: null,
        replaceState: (_state: unknown, _title: string, url: string) => replacements.push(url),
      },
    },
  });
  exports.default!.bootstrap({});
  assert.deepEqual(replacements, ['/admin/auth/login']);
});
