module.exports = {
  // Test environment
  testEnvironment: 'node',
  
  // Test match patterns
  testMatch: [
    '**/__tests__/**/*.[jt]s?(x)',
    '**/?(*.)+(spec|test).[tj]s?(x)'
  ],
  
  // Files to ignore
  testPathIgnorePatterns: [
    '/node_modules/',
    '/webapp/node_modules/',
    '/environments/',
    '/modules/',
    '/.terraform/'
  ],
  
  // Coverage settings
  collectCoverageFrom: [
    '**/*.{js,jsx}',
    '!**/node_modules/**',
    '!**/coverage/**',
    '!**/jest.config.js',
    '!**/webpack.config.js'
  ],
  
  // Verbose output
  verbose: true,
  
  // Pass with no tests
  passWithNoTests: true,
  
  // Timeout for tests
  testTimeout: 10000,
  
  // Setup files
  setupFilesAfterEnv: [],
  
  // Mock settings
  clearMocks: true,
  restoreMocks: true,
  
  // Transform settings
  transform: {
    '^.+\\.js$': 'babel-jest'
  },
  
  // Module file extensions
  moduleFileExtensions: ['js', 'json', 'jsx', 'node']
}; 