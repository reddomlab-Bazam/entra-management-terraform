// Basic test to verify Jest setup
describe('Project Setup', () => {
  test('should have working test environment', () => {
    expect(true).toBe(true);
  });

  test('should have Node.js environment available', () => {
    expect(process.env.NODE_ENV || 'development').toBeDefined();
  });

  test('should be able to require package.json', () => {
    const packageJson = require('../package.json');
    expect(packageJson.name).toBe('entra-management-console');
    expect(packageJson.version).toBeDefined();
  });
}); 