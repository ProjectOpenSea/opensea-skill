#!/usr/bin/env npx tsx
/**
 * Sync ecosystem partner skill references from upstream repos.
 *
 * Reads packages/skill/ecosystem/sync.config.json, clones each partner's
 * upstream repo (shallow), and copies references/ into the corresponding
 * ecosystem/<vendor>-<skill>/references/ directory. Stamps .upstream.json
 * with the upstream SHA so reviewers can verify provenance at a glance.
 *
 * SKILL.md, LICENSE.txt, and agents/ are NOT touched — those are
 * human-curated (description, handoff table, env block). The bot only
 * keeps the bulk of reference docs fresh.
 *
 * Usage:
 *   pnpm sync-ecosystem            # apply changes
 *   pnpm sync-ecosystem --check    # verify references are in sync (CI)
 */

import { execSync } from "node:child_process"
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs"
import { tmpdir } from "node:os"
import { dirname, extname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const __dirname = dirname(fileURLToPath(import.meta.url))
const SKILL_PKG = resolve(__dirname, "..")
const ECOSYSTEM_DIR = join(SKILL_PKG, "ecosystem")
const MANIFEST_PATH = join(ECOSYSTEM_DIR, "sync.config.json")

const CHECK_MODE = process.argv.includes("--check")

interface SkillMapping {
  from: string
  to: string
  dirs?: string[]
}

const DEFAULT_SYNC_DIRS = ["references"]

interface Rewrite {
  from: string
  to: string
  reason?: string
}

interface Partner {
  vendor: string
  upstream: string
  ref: string
  pinned_sha?: string
  skills: SkillMapping[]
  rewrites?: Rewrite[]
}

const ALLOWED_EXTENSIONS = new Set([".md"])
const REPORT_PATH = join(
  process.env.RUNNER_TEMP || tmpdir(),
  "sync-ecosystem-flags.md",
)

interface ContentFlag {
  file: string
  line: number
  kind: string
  excerpt: string
}

const FLAG_RULES: { kind: string; pattern: RegExp }[] = [
  { kind: "ethereum-address", pattern: /0x[a-fA-F0-9]{40}\b/ },
  {
    kind: "prompt-injection",
    pattern:
      /\b(ignore (?:previous|prior|the above) (?:instructions?|prompt)|you are now|system:|<\|im_start\|>|<\|im_end\|>|disregard (?:previous|prior))/i,
  },
  { kind: "long-base64", pattern: /[A-Za-z0-9+/]{120,}={0,2}/ },
  {
    kind: "private-key",
    pattern:
      /-----BEGIN (?:RSA |EC |OPENSSH |PGP |ENCRYPTED |DSA )?PRIVATE KEY-----/,
  },
]

interface Manifest {
  partners: Partner[]
}

interface UpstreamStamp {
  upstream: string
  ref: string
  sha: string
  from: string
  synced_at: string
}

interface SyncResult {
  added: string[]
  modified: string[]
  removed: string[]
  skipped: string[]
  flags: ContentFlag[]
}

function scanContent(
  rel: string,
  content: Buffer,
  priorContent: Buffer | null,
): ContentFlag[] {
  const flags: ContentFlag[] = []
  const lines = content.toString("utf8").split("\n")
  const priorLines = priorContent
    ? new Set(priorContent.toString("utf8").split("\n"))
    : null
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (priorLines && priorLines.has(line)) continue
    for (const rule of FLAG_RULES) {
      if (rule.pattern.test(line)) {
        flags.push({
          file: rel,
          line: i + 1,
          kind: rule.kind,
          excerpt: line.length > 200 ? `${line.slice(0, 200)}…` : line,
        })
      }
    }
  }
  return flags
}

function sh(cmd: string, opts: { cwd?: string } = {}): string {
  return execSync(cmd, {
    ...opts,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  }).trim()
}

function listFilesRecursive(dir: string): string[] {
  const out: string[] = []
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name)
    if (entry.isDirectory()) out.push(...listFilesRecursive(full))
    else out.push(full)
  }
  return out
}

function relativize(file: string, base: string): string {
  return file.slice(base.length + 1)
}

function applyRewrites(content: Buffer, rewrites: Rewrite[]): Buffer {
  if (rewrites.length === 0) return content
  let text = content.toString("utf8")
  for (const r of rewrites) {
    text = text.split(r.from).join(r.to)
  }
  return Buffer.from(text, "utf8")
}

function syncReferences(
  srcDir: string,
  destDir: string,
  rewrites: Rewrite[],
  relPrefix: string,
): SyncResult {
  const result: SyncResult = {
    added: [],
    modified: [],
    removed: [],
    skipped: [],
    flags: [],
  }

  const srcExists = existsSync(srcDir)
  const destExists = existsSync(destDir)

  if (!srcExists && !destExists) return result

  if (!srcExists) {
    for (const f of listFilesRecursive(destDir)) {
      result.removed.push(relativize(f, destDir))
    }
    if (!CHECK_MODE) rmSync(destDir, { recursive: true })
    return result
  }

  const allSrcFiles = listFilesRecursive(srcDir).map(f => relativize(f, srcDir))
  const srcFiles = new Set<string>()
  for (const rel of allSrcFiles) {
    if (ALLOWED_EXTENSIONS.has(extname(rel))) {
      srcFiles.add(rel)
    } else {
      result.skipped.push(rel)
    }
  }
  const destFiles = destExists
    ? new Set(listFilesRecursive(destDir).map(f => relativize(f, destDir)))
    : new Set<string>()

  for (const rel of srcFiles) {
    const srcFile = join(srcDir, rel)
    const destFile = join(destDir, rel)
    const srcContent = applyRewrites(readFileSync(srcFile), rewrites)
    const priorContent = destFiles.has(rel) ? readFileSync(destFile) : null
    const isAdd = priorContent === null
    const isModify = priorContent !== null && !srcContent.equals(priorContent)
    if (isAdd) {
      result.added.push(rel)
      if (!CHECK_MODE) {
        mkdirSync(dirname(destFile), { recursive: true })
        writeFileSync(destFile, srcContent)
      }
    } else if (isModify) {
      result.modified.push(rel)
      if (!CHECK_MODE) writeFileSync(destFile, srcContent)
    }
    if (isAdd || isModify) {
      result.flags.push(
        ...scanContent(`${relPrefix}/${rel}`, srcContent, priorContent),
      )
    }
  }

  for (const rel of destFiles) {
    if (!srcFiles.has(rel)) {
      result.removed.push(rel)
      if (!CHECK_MODE) rmSync(join(destDir, rel))
    }
  }

  return result
}

function writeStamp(skillDir: string, stamp: UpstreamStamp): void {
  if (CHECK_MODE) return
  writeFileSync(
    join(skillDir, ".upstream.json"),
    JSON.stringify(stamp, null, 2) + "\n",
  )
}

function readManifest(): Manifest {
  return JSON.parse(readFileSync(MANIFEST_PATH, "utf8"))
}

function cloneUpstream(partner: Partner, dest: string): string {
  if (partner.pinned_sha) {
    sh(`git init --quiet ${dest}`)
    sh(`git remote add origin ${partner.upstream}`, { cwd: dest })
    sh(`git fetch --quiet --depth=1 origin ${partner.pinned_sha}`, {
      cwd: dest,
    })
    sh("git checkout --quiet FETCH_HEAD", { cwd: dest })
    return partner.pinned_sha
  }
  sh(
    `git clone --quiet --depth=1 --branch ${partner.ref} ${partner.upstream} ${dest}`,
  )
  return sh("git rev-parse HEAD", { cwd: dest })
}

function renderFlagReport(
  flags: { partner: string; flags: ContentFlag[] }[],
): string {
  const all = flags.flatMap(p =>
    p.flags.map(f => ({ ...f, partner: p.partner })),
  )
  if (all.length === 0) return ""
  const lines: string[] = []
  lines.push("## Content scan flags")
  lines.push("")
  lines.push(
    "The following lines tripped a heuristic content-scan rule. These are NOT necessarily malicious — review and confirm each one looks legitimate before merging. False positives are common (e.g. an ethereum address in a legitimate code example is benign; an ethereum address in a freshly-added paragraph that wasn't there before deserves scrutiny).",
  )
  lines.push("")
  lines.push("| Partner | File | Line | Rule | Excerpt |")
  lines.push("|---|---|---|---|---|")
  for (const f of all) {
    const safeExcerpt = f.excerpt.replace(/\|/g, "\\|").replace(/`/g, "'")
    lines.push(
      `| ${f.partner} | \`${f.file}\` | ${f.line} | ${f.kind} | \`${safeExcerpt}\` |`,
    )
  }
  lines.push("")
  return lines.join("\n")
}

async function main(): Promise<void> {
  const manifest = readManifest()
  let drift = 0
  const partnerFlags: { partner: string; flags: ContentFlag[] }[] = []
  let totalSkipped = 0

  const failedPartners: string[] = []

  for (const partner of manifest.partners) {
    const cloneDir = mkdtempSync(join(tmpdir(), `sync-${partner.vendor}-`))
    const flags: ContentFlag[] = []
    try {
      const sha = cloneUpstream(partner, cloneDir)
      const pinSuffix = partner.pinned_sha ? ` (pinned)` : ""
      console.log(
        `\n[${partner.vendor}] ${partner.upstream}@${partner.ref} sha=${sha.slice(0, 7)}${pinSuffix}`,
      )

      const missing = partner.skills
        .map(s => s.from)
        .filter(from => !existsSync(join(cloneDir, from)))
      if (missing.length > 0) {
        console.error(
          `  ABORTED for partner '${partner.vendor}': upstream paths missing — likely a rename or removal:\n${missing.map(p => `    - ${p}`).join("\n")}\n  Update sync.config.json before re-running. Local content was left untouched.`,
        )
        failedPartners.push(partner.vendor)
        continue
      }

      for (const skill of partner.skills) {
        const destSkill = resolve(SKILL_PKG, skill.to)

        if (!existsSync(destSkill)) {
          console.log(
            `  ${skill.to}: SKIP (not materialized — bootstrap manually first)`,
          )
          continue
        }

        const dirs = skill.dirs ?? DEFAULT_SYNC_DIRS
        let change = 0
        const dirSummaries: string[] = []
        for (const dir of dirs) {
          const srcDir = join(cloneDir, skill.from, dir)
          const destDir = join(destSkill, dir)
          const r = syncReferences(
            srcDir,
            destDir,
            partner.rewrites ?? [],
            `${skill.to}/${dir}`,
          )
          const dirChange =
            r.added.length + r.modified.length + r.removed.length
          change += dirChange
          drift += dirChange
          totalSkipped += r.skipped.length
          flags.push(...r.flags)
          if (dirChange > 0 || r.skipped.length > 0) {
            const segments = [
              `${dir}/`,
              `+${r.added.length}`,
              `~${r.modified.length}`,
              `-${r.removed.length}`,
            ]
            if (r.skipped.length > 0) segments.push(`!${r.skipped.length}`)
            dirSummaries.push(segments.join(" "))
            for (const f of r.added) console.log(`    A ${dir}/${f}`)
            for (const f of r.modified) console.log(`    M ${dir}/${f}`)
            for (const f of r.removed) console.log(`    D ${dir}/${f}`)
            for (const f of r.skipped)
              console.log(
                `    ! ${dir}/${f} (skipped — non-allowlisted extension)`,
              )
          }
        }

        const summary =
          dirSummaries.length > 0 ? dirSummaries.join(", ") : "no changes"
        console.log(`  ${skill.to}: ${summary}`)

        const stampPath = join(destSkill, ".upstream.json")
        const stampMissing = !existsSync(stampPath)
        const shaChanged =
          !stampMissing &&
          JSON.parse(readFileSync(stampPath, "utf8")).sha !== sha

        if (change > 0 || stampMissing || shaChanged) {
          writeStamp(destSkill, {
            upstream: partner.upstream,
            ref: partner.ref,
            sha,
            from: skill.from,
            synced_at: new Date().toISOString(),
          })
        }
      }
    } finally {
      rmSync(cloneDir, { recursive: true, force: true })
    }
    if (flags.length > 0) partnerFlags.push({ partner: partner.vendor, flags })
  }

  const report = renderFlagReport(partnerFlags)
  if (!CHECK_MODE) {
    writeFileSync(REPORT_PATH, report)
  }
  if (report) {
    console.log("\n--- content scan flags ---")
    console.log(report)
  }
  if (totalSkipped > 0) {
    console.log(
      `\nSkipped ${totalSkipped} file(s) due to non-allowlisted extension (only .md is synced).`,
    )
  }

  if (failedPartners.length > 0) {
    console.error(
      `\nAborted for ${failedPartners.length} partner(s) due to missing upstream paths: ${failedPartners.join(", ")}. Fix sync.config.json.`,
    )
    process.exit(1)
  }

  if (CHECK_MODE && drift > 0) {
    console.error(
      `\nReferences drifted by ${drift} file(s). Run \`pnpm sync-ecosystem\` to update.`,
    )
    process.exit(1)
  }
  console.log("\nDone.")
}

main().catch(err => {
  console.error(err)
  process.exit(1)
})
