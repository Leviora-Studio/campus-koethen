import { parseUserTestSeedMode } from './seed-user-test-data';

describe('parseUserTestSeedMode', () => {
  it('seeds by default and supports preview or scoped removal', () => {
    expect(parseUserTestSeedMode([])).toBe('seed');
    expect(parseUserTestSeedMode(['--dry-run'])).toBe('dry-run');
    expect(parseUserTestSeedMode(['--remove'])).toBe('remove');
  });

  it('rejects conflicting or unknown arguments', () => {
    expect(() => parseUserTestSeedMode(['--dry-run', '--remove'])).toThrow();
    expect(() => parseUserTestSeedMode(['--force'])).toThrow();
  });
});
