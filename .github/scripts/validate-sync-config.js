#!/usr/bin/env node
'use strict';

/*
 * Validator dan perencana sinkronisasi branch untuk konfigurasi sumber kebenaran tunggal.
 * Digunakan oleh .github/workflows/sync-branches.yml.
 * Tidak bergantung pada paket npm eksternal (Node.js bawaan hanya).
 *
 * Usage:
 *   node validate-sync-config.js validate [config-path]
 *   node validate-sync-config.js children <source> [config-path]
 *
 * Exit code:
 *   0 = sukses / skip aman
 *   1 = kesalahan validasi konfigurasi (hentikan sebelum operasi Git)
 *   2 = kesalahan penggunaan / pembacaan berkas
 */

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const DEFAULT_CONFIG = path.resolve(__dirname, '..', 'sync-config.yaml');

function fail(message, code = 2) {
  console.error(`::error::${message}`);
  process.exit(code);
}

function makeError(message) {
  return { level: 'error', message };
}

function parseYaml(content) {
  const lines = content.split(/\r?\n/);
  const root = { sources: Object.create(null) };
  const seenSources = new Set();
  let inSources = false;
  let currentSource = null;

  for (let index = 0; index < lines.length; index++) {
    const rawLine = lines[index];
    const line = rawLine.replace(/(^|\s)#.*$/, '').replace(/\s+$/, '');
    if (line.trim() === '') continue;

    const indent = line.length - line.trimStart().length;
    const text = line.trim();

    if (indent === 0) {
      if (text === 'sources:') {
        inSources = true;
        currentSource = null;
        continue;
      }
      throw makeError(`STRUCTURE_ERROR: kunci tingkat atas tidak dikenal '${text}' (hanya 'sources' yang diizinkan)`);
    }

    if (!inSources) {
      throw makeError(`STRUCTURE_ERROR: konten di luar blok 'sources' (baris ${index + 1})`);
    }

    if (indent === 2 && text.endsWith(':') && !text.startsWith('- ')) {
      const sourceName = text.slice(0, -1).trim();
      if (sourceName === '') throw makeError(`STRUCTURE_ERROR: nama source kosong (baris ${index + 1})`);
      if (seenSources.has(sourceName)) {
        throw makeError(`STRUCTURE_ERROR: duplicate source '${sourceName}' (baris ${index + 1})`);
      }
      seenSources.add(sourceName);
      currentSource = sourceName;
      root.sources[currentSource] = [];
      continue;
    }

    if (indent === 4 && text.startsWith('- ')) {
      if (currentSource === null) {
        throw makeError(`STRUCTURE_ERROR: item child tanpa source (baris ${index + 1})`);
      }
      const child = text.slice(2).trim();
      if (child === '') throw makeError(`STRUCTURE_ERROR: nama child kosong di bawah '${currentSource}' (baris ${index + 1})`);
      root.sources[currentSource].push(child);
      continue;
    }

    throw makeError(`STRUCTURE_ERROR: baris tidak valid (indent=${indent}) pada baris ${index + 1}: ${rawLine}`);
  }

  return root;
}

function readConfig(configPath) {
  if (!fs.existsSync(configPath)) {
    fail(`CONFIG_NOT_FOUND: berkas konfigurasi '${configPath}' tidak ditemukan`, 2);
  }
  const content = fs.readFileSync(configPath, 'utf8');
  try {
    return parseYaml(content);
  } catch (err) {
    if (err && err.level === 'error') fail(`YAML_ERROR: ${err.message}`, 1);
    fail(`YAML_ERROR: ${err.message}`, 1);
  }
}

function validateConfig(config) {
  const errors = [];
  const sources = config.sources;

  if (sources === null || typeof sources !== 'object' || Array.isArray(sources)) {
    errors.push(makeError('STRUCTURE_ERROR: "sources" harus berupa mapping/objek'));
    return errors;
  }

  const parentOf = Object.create(null);
  const visited = new Set();
  const recursionStack = new Set();

  for (const [source, children] of Object.entries(sources)) {
    if (typeof source !== 'string' || source.trim() === '') {
      errors.push(makeError('RELATION_ERROR: nama source kosong'));
      continue;
    }
    const sourceValidation = isValidBranchName(source);
    if (sourceValidation.error) {
      errors.push(makeError(`BRANCH_VALIDATION_ERROR: git check-ref-format gagal: ${sourceValidation.error}`));
    } else if (!sourceValidation.valid) {
      errors.push(makeError(`BRANCH_ERROR: nama source '${source}' bukan branch Git yang valid`));
    }

    if (!Array.isArray(children)) {
      errors.push(makeError(`STRUCTURE_ERROR: source '${source}' harus memiliki daftar child (array)`));
      continue;
    }

    const seenChildren = new Set();
    for (const child of children) {
      if (typeof child !== 'string' || child.trim() === '') {
        errors.push(makeError(`STRUCTURE_ERROR: source '${source}' memiliki child kosong/bukan string`));
        continue;
      }
      const childValidation = isValidBranchName(child);
      if (childValidation.error) {
        errors.push(makeError(`BRANCH_VALIDATION_ERROR: git check-ref-format gagal: ${childValidation.error}`));
      } else if (!childValidation.valid) {
        errors.push(makeError(`BRANCH_ERROR: nama child '${child}' bukan branch Git yang valid`));
      }
      if (child === 'main') {
        errors.push(makeError("RELATION_ERROR: branch 'main' tidak boleh menjadi child sinkronisasi"));
      }

      if (seenChildren.has(child)) {
        errors.push(makeError(`RELATION_ERROR: duplicate child '${child}' di bawah source '${source}'`));
      }
      seenChildren.add(child);

      if (child === source) {
        errors.push(makeError(`RELATION_ERROR: self-reference: source '${source}' adalah childnya sendiri`));
      }

      if (parentOf[child] !== undefined && parentOf[child] !== source) {
        errors.push(makeError(`RELATION_ERROR: multiple parent untuk child '${child}': '${parentOf[child]}' dan '${source}'`));
      } else {
        parentOf[child] = source;
      }
    }
  }

  function hasCycle(node) {
    if (recursionStack.has(node)) return true;
    if (visited.has(node)) return false;
    visited.add(node);
    recursionStack.add(node);
    for (const child of (sources[node] || [])) {
      if (hasCycle(child)) return true;
    }
    recursionStack.delete(node);
    return false;
  }

  for (const source of Object.keys(sources)) {
    if (hasCycle(source)) {
      errors.push(makeError('RELATION_ERROR: siklus terdeteksi dalam hierarki source-child'));
      break;
    }
  }

  return errors;
}

function getChildren(config, source) {
  const sources = config.sources || {};
  if (!(source in sources)) {
    return { skipped: 'SOURCE_NOT_CONFIGURED' };
  }
  const children = sources[source] || [];
  if (children.length === 0) {
    return { skipped: 'NO_DIRECT_CHILDREN' };
  }
  return { children };
}

function isValidBranchName(name) {
  const result = spawnSync('git', ['check-ref-format', '--branch', name], {
    encoding: 'utf8',
  });
  if (result.error) {
    return { valid: false, error: result.error.message };
  }
  return { valid: result.status === 0 };
}

const [mode, arg1, arg2] = process.argv.slice(2);
let resolvedConfig;
let source;

switch (mode) {
  case 'validate':
    resolvedConfig = arg1 || DEFAULT_CONFIG;
    break;
  case 'children':
    source = arg1;
    resolvedConfig = arg2 || DEFAULT_CONFIG;
    break;
  default:
    fail(`Usage:\n  node ${path.basename(__filename)} validate [config-path]\n  node ${path.basename(__filename)} children <source> [config-path]`, 2);
}

if (mode === 'validate') {
  const config = readConfig(resolvedConfig);
  const errors = validateConfig(config);
  if (errors.length) {
    console.error('Konfigurasi sinkronisasi tidak valid:');
    for (const err of errors) console.error(`- ${err.message}`);
    process.exit(1);
  }
  console.log('OK: konfigurasi sinkronisasi valid');
  process.exit(0);
}

if (mode === 'children') {
  if (!source) fail('USAGE: children <source> [config-path]', 2);
  const config = readConfig(resolvedConfig);
  const result = getChildren(config, source);
  if (result.skipped) {
    console.log(`SKIPPED: ${result.skipped}`);
    process.exit(0);
  }
  for (const child of result.children) console.log(child);
  process.exit(0);
}