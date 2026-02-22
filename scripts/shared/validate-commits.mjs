#!/usr/bin/env node
// =============================================================================
// validate-commits.mjs
// Validates git commit messages against the Conventional Commits specification.
// Uses @commitlint/core + @commitlint/config-conventional.
//
// Usage:
//   node validate-commits.mjs [FROM_SHA] [TO_SHA]
//
// Arguments:
//   FROM_SHA   Start of commit range (exclusive). Default: merge-base of HEAD and base branch.
//   TO_SHA     End of commit range (inclusive).   Default: HEAD
//
// Environment:
//   BASE_BRANCH      Base branch for range detection (default: "main")
//   QA_OUTPUT_DIR    Directory for JSON output file (default: /tmp)
//   GITHUB_OUTPUT    Path to GHA output file (set automatically in Actions)
//
// Outputs (GITHUB_OUTPUT + JSON at $QA_OUTPUT_DIR/qa-validate-commits-output.json):
//   commits_valid    "true" | "false"
//   total_count      Total number of commits analysed
//   invalid_count    Number of invalid commits
//   output_file      Path to the generated JSON output file
//
// Exit codes:
//   0  All commits valid (or validation completed — enforcement is caller's job)
//   1  Fatal error (git failure, missing deps, etc.)
// =============================================================================

import { execSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync, appendFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ── Helpers ───────────────────────────────────────────────────────────────────
const isCI = !!process.env.GITHUB_ACTIONS;

const log = {
  info:    (...a) => console.log('ℹ ', ...a),
  success: (...a) => console.log('✅', ...a),
  warn:    (...a) => console.warn('⚠️ ', ...a),
  error:   (...a) => console.error('❌', ...a),
  step:    (...a) => console.log('\n▶', ...a),
  debug:   (...a) => process.env.DEBUG === '1' && console.log('[debug]', ...a),
};

function ghaOutput(key, value) {
  const ghOutput = process.env.GITHUB_OUTPUT;
  if (!ghOutput) return log.debug(`GITHUB_OUTPUT not set — skipping: ${key}`);
  appendFileSync(ghOutput, `${key}<<__GHA_EOF__\n${value}\n__GHA_EOF__\n`);
  log.debug(`GITHUB_OUTPUT: ${key}=${value}`);
}

function ghaAnnotation(type, title, message) {
  if (!isCI) return;
  console.log(`::${type} title=${title}::${message}`);
}

function writeJSON(filePath, data) {
  mkdirSync(dirname(filePath), { recursive: true });
  writeFileSync(filePath, JSON.stringify(data, null, 2));
  log.debug(`JSON written to: ${filePath}`);
}

function run(cmd, opts = {}) {
  try {
    return execSync(cmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], ...opts }).trim();
  } catch (e) {
    throw new Error(`Command failed: ${cmd}\n${e.stderr || e.message}`);
  }
}

// ── Dependency bootstrap ──────────────────────────────────────────────────────
log.step('Checking dependencies');

const DEPS = ['@commitlint/core', '@commitlint/config-conventional'];
const INSTALL_DIR = resolve(__dirname, '../../.commitlint-deps');

function ensureDeps() {
  const pkgCheck = resolve(INSTALL_DIR, 'node_modules/@commitlint/core/package.json');
  if (existsSync(pkgCheck)) {
    log.debug('Dependencies already installed, skipping.');
    return;
  }
  log.info(`Installing commitlint dependencies to ${INSTALL_DIR}...`);
  mkdirSync(INSTALL_DIR, { recursive: true });
  if (!existsSync(resolve(INSTALL_DIR, 'package.json'))) {
    writeFileSync(resolve(INSTALL_DIR, 'package.json'), '{"type":"module"}');
  }
  const result = spawnSync(
    'npm', ['install', '--save', '--prefix', INSTALL_DIR, ...DEPS],
    { stdio: 'inherit', encoding: 'utf8' }
  );
  if (result.status !== 0) throw new Error('Failed to install commitlint dependencies.');
  log.success('Dependencies installed.');
}

ensureDeps();

// Dynamic import from local install dir
const require = createRequire(resolve(INSTALL_DIR, 'package.json'));
const { lint }         = await import(resolve(INSTALL_DIR, 'node_modules/@commitlint/core/lib/index.js'));
const { default: load } = await import(resolve(INSTALL_DIR, 'node_modules/@commitlint/core/lib/load.js'));

const commitlintConfig = await load(
  { extends: ['@commitlint/config-conventional'] },
  { cwd: INSTALL_DIR }
);

// ── Determine commit range ─────────────────────────────────────────────────────
log.step('Resolving commit range');

const BASE_BRANCH  = process.env.BASE_BRANCH || 'main';
const [fromArg, toArg] = process.argv.slice(2);

let fromSha = fromArg;
let toSha   = toArg || 'HEAD';

if (!fromSha) {
  try {
    fromSha = run(`git merge-base HEAD origin/${BASE_BRANCH}`);
    log.info(`Merge-base with origin/${BASE_BRANCH}: ${fromSha.slice(0, 8)}`);
  } catch {
    try {
      fromSha = run(`git rev-parse HEAD~1`);
      log.warn(`Could not find merge-base. Falling back to HEAD~1.`);
    } catch {
      fromSha = run(`git rev-list --max-parents=0 HEAD`);
      log.warn(`Falling back to root commit.`);
    }
  }
}

log.info(`Range: ${fromSha.slice(0, 8)}..${toSha}`);

// ── Collect commits ────────────────────────────────────────────────────────────
log.step('Collecting commits');

const gitLog = run(`git log "${fromSha}..${toSha}" --pretty=format:"%H %s"`);

if (!gitLog) {
  log.warn('No commits found in range. Nothing to validate.');
  const output = { commits_valid: true, total_count: 0, invalid_count: 0, results: [] };
  const outputFile = resolve(process.env.QA_OUTPUT_DIR || '/tmp', 'qa-validate-commits-output.json');
  writeJSON(outputFile, output);
  ghaOutput('commits_valid',  'true');
  ghaOutput('total_count',    '0');
  ghaOutput('invalid_count',  '0');
  ghaOutput('output_file',    outputFile);
  process.exit(0);
}

const commits = gitLog.split('\n').filter(Boolean).map(line => {
  const sha     = line.slice(0, 40);
  const message = line.slice(41).trim();
  return { sha, shortSha: sha.slice(0, 8), message };
});

log.info(`Found ${commits.length} commit(s) to validate.`);

// ── Validate ──────────────────────────────────────────────────────────────────
log.step('Validating commits');

const results = [];
let invalidCount = 0;

for (const commit of commits) {
  const { valid, errors, warnings } = await lint(commit.message, commitlintConfig.rules, {
    defaultIgnores: commitlintConfig.defaultIgnores,
    ignores:        commitlintConfig.ignores,
    parserOpts:     commitlintConfig.parserPreset?.parserOpts,
  });

  const result = {
    sha:      commit.sha,
    shortSha: commit.shortSha,
    message:  commit.message,
    valid,
    errors:   errors.map(e => e.message),
    warnings: warnings.map(w => w.message),
  };

  results.push(result);

  if (!valid) {
    invalidCount++;
    log.warn(`INVALID [${commit.shortSha}] ${commit.message}`);
    errors.forEach(e => {
      log.error(`  → ${e.message}`);
      ghaAnnotation('warning', 'Invalid Commit', `${commit.shortSha}: ${commit.message} — ${e.message}`);
    });
  } else {
    log.debug(`  valid [${commit.shortSha}] ${commit.message}`);
  }
}

// ── Output ────────────────────────────────────────────────────────────────────
const isValid    = invalidCount === 0;
const outputDir  = process.env.QA_OUTPUT_DIR || '/tmp';
const outputFile = resolve(outputDir, 'qa-validate-commits-output.json');

const output = {
  commits_valid: isValid,
  total_count:   commits.length,
  invalid_count: invalidCount,
  range: { from: fromSha, to: toSha, base_branch: BASE_BRANCH },
  results,
};

writeJSON(outputFile, output);

ghaOutput('commits_valid',  String(isValid));
ghaOutput('total_count',    String(commits.length));
ghaOutput('invalid_count',  String(invalidCount));
ghaOutput('output_file',    outputFile);

if (isValid) {
  log.success(`All ${commits.length} commit(s) are valid.`);
} else {
  log.warn(`${invalidCount} of ${commits.length} commit(s) are invalid.`);
  log.info('Enforcement (block/info) is handled by the calling workflow.');
}

// Always exit 0 — enforcement is the caller's responsibility
process.exit(0);
