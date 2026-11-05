const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const catalog = path.join(root, 'SKILL.md');
const skillsRoot = path.join(root, '.agents', 'skills');
const errors = [];
const names = new Set();

function markdownFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) return markdownFiles(fullPath);
    return entry.isFile() && entry.name.endsWith('.md') ? [fullPath] : [];
  });
}

function validateSkill(file) {
  const content = fs.readFileSync(file, 'utf8');
  const match = content.match(/^---\s*\r?\n([\s\S]*?)\r?\n---\s*(?:\r?\n|$)/);
  const relative = path.relative(root, file).replaceAll(path.sep, '/');
  if (!match) {
    errors.push(`${relative}: missing YAML frontmatter`);
    return;
  }

  const name = match[1].match(/^name:\s*([^\r\n]+)$/m)?.[1]?.trim();
  const description = match[1].match(/^description:\s*(.+)$/m)?.[1]?.trim();
  if (!name) errors.push(`${relative}: missing name`);
  else if (names.has(name)) errors.push(`${relative}: duplicate skill name ${name}`);
  else names.add(name);
  if (!description) errors.push(`${relative}: missing description`);
}

function validateLinks(file) {
  const content = fs.readFileSync(file, 'utf8');
  const relative = path.relative(root, file).replaceAll(path.sep, '/');
  for (const match of content.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)) {
    const target = match[1].split('#')[0];
    if (!target || /^[a-z][a-z\d+.-]*:/i.test(target) || target.startsWith('/')) continue;
    const resolved = path.resolve(path.dirname(file), decodeURIComponent(target));
    if (!resolved.startsWith(`${root}${path.sep}`) && resolved !== root) {
      errors.push(`${relative}: link escapes repository: ${target}`);
    } else if (!fs.existsSync(resolved)) {
      errors.push(`${relative}: missing link target ${target}`);
    }
  }
}

if (!fs.existsSync(skillsRoot)) {
  console.error('Missing .agents/skills directory');
  process.exit(1);
}

const files = [catalog, ...markdownFiles(skillsRoot)];
for (const file of files) {
  if (file !== catalog) validateSkill(file);
  validateLinks(file);
}

if (errors.length) {
  console.error(errors.map((error) => `- ${error}`).join('\n'));
  process.exit(1);
}

console.log(`Validated ${names.size} skills and links in ${files.length} Markdown files.`);