import { requireDatabaseUrl } from './database';
describe('destructive test database protection', () => {
  const previous = process.env['DATABASE_URL'];
  afterEach(() => {
    if (previous === undefined) delete process.env['DATABASE_URL'];
    else process.env['DATABASE_URL'] = previous;
  });
  it('refuses a development/production database before a connection or truncation', () => {
    process.env['DATABASE_URL'] = 'postgresql://demo:demo@localhost/campus_app';
    expect(() => requireDatabaseUrl()).toThrow(/test database/i);
  });
  it('refuses a connection parameter that could override the guarded database', () => {
    process.env['DATABASE_URL'] = 'postgresql://localhost/campus_audit_test?database=campus_app';
    expect(() => requireDatabaseUrl()).toThrow(/test database/i);
  });
  it('allows an explicitly named isolated test database', () => {
    process.env['DATABASE_URL'] = 'postgresql://demo:demo@localhost/campus_audit_test';
    expect(requireDatabaseUrl()).toContain('/campus_audit_test');
  });
});
