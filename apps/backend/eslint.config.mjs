// @ts-check
import eslint from '@eslint/js';
import eslintConfigPrettier from 'eslint-config-prettier';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    // Generated Prisma client and build output are not ours to lint.
    ignores: ['eslint.config.mjs', 'dist/**', 'src/generated/**', 'coverage/**'],
  },
  eslint.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  // Turns off rules that would fight Prettier. Formatting itself is checked
  // once, repo-wide, by `pnpm format:check` — running Prettier through ESLint
  // as well would only duplicate the work and the failure messages.
  eslintConfigPrettier,
  {
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.jest,
      },
      sourceType: 'commonjs',
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  {
    rules: {
      // AGENTS.md: no `any` without a justified, commented exception. Keeping
      // this at error is the point — the Nest scaffold switched it off.
      '@typescript-eslint/no-explicit-any': 'error',
      // An unawaited promise in a request handler or a sync run is a real bug,
      // not a style preference.
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-unsafe-argument': 'warn',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
    },
  },
  {
    // Tests deliberately feed malformed and unexpected shapes through the
    // parsers, which is exactly what the unsafe-* rules flag.
    files: ['**/*.spec.ts', 'test/**/*.ts'],
    rules: {
      '@typescript-eslint/no-unsafe-assignment': 'off',
      '@typescript-eslint/no-unsafe-member-access': 'off',
      '@typescript-eslint/no-unsafe-argument': 'off',
      '@typescript-eslint/no-unsafe-call': 'off',
      // Stubs are declared async to match the real signature they replace,
      // even when the fake body has nothing to await.
      '@typescript-eslint/require-await': 'off',
    },
  },
);
