const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const extensions = new Set(['.js', '.json']);
const excludedDirs = new Set(['node_modules', '.git']);
const failures = [];

function collectFiles(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.isDirectory() && excludedDirs.has(entry.name)) continue;
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) collectFiles(fullPath);
    else if (entry.isFile() && extensions.has(path.extname(entry.name))) checkFile(fullPath);
  }
}

function checkFile(file) {
  const relative = path.relative(root, file);
  const content = fs.readFileSync(file, 'utf8');
  const lines = content.split(/\r?\n/);
  lines.forEach((line, index) => {
    if (/[\t ]+$/.test(line)) failures.push(`${relative}:${index + 1}: trailing whitespace`);
  });

  if (path.extname(file) === '.json') {
    try {
      JSON.parse(content);
    } catch (error) {
      failures.push(`${relative}: invalid JSON (${error.message})`);
    }
  }
}

collectFiles(root);

if (failures.length) {
  console.error(failures.map((failure) => `- ${failure}`).join('\n'));
  process.exit(1);
}

console.log('Formatting check passed (trailing whitespace and JSON syntax).');