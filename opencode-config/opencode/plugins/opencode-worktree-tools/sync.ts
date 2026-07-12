import { lstat, mkdir, realpath, rm, symlink, stat } from "node:fs/promises";
import * as path from "node:path";
import { isPathSafe } from "./validate";

function isWithinRoot(rootReal: string, candidateReal: string): boolean {
  const relative = path.relative(rootReal, candidateReal);
  return relative === "" || (!!relative && !relative.startsWith("..") && !path.isAbsolute(relative));
}

async function resolveExistingWithinRoot(rootDir: string, relativePath: string): Promise<string | null> {
  const rootReal = await realpath(rootDir).catch(() => null);
  if (!rootReal) return null;

  const candidateReal = await realpath(path.resolve(rootDir, relativePath)).catch(() => null);
  if (!candidateReal || !isWithinRoot(rootReal, candidateReal)) return null;
  return candidateReal;
}

async function ensureDirWithinRoot(rootDir: string, relativeDir: string): Promise<string | null> {
  const rootReal = await realpath(rootDir).catch(() => null);
  if (!rootReal) return null;

  const targetDir = path.resolve(rootDir, relativeDir);
  const rel = path.relative(rootDir, targetDir);
  if (rel && (rel.startsWith("..") || path.isAbsolute(rel))) return null;

  let cursor = rootDir;
  for (const part of rel.split(path.sep).filter(Boolean)) {
    cursor = path.join(cursor, part);
    const entry = await lstat(cursor).catch(() => null);
    if (entry?.isSymbolicLink()) return null;
    if (entry && !entry.isDirectory()) return null;
    if (!entry) await mkdir(cursor);
  }

  const finalReal = await realpath(targetDir).catch(() => null);
  if (!finalReal || !isWithinRoot(rootReal, finalReal)) return null;
  return targetDir;
}

export async function copyFiles(
  sourceDir: string,
  targetDir: string,
  files: string[],
  log: (msg: string) => void,
): Promise<void> {
  for (const file of files) {
    if (!isPathSafe(file, sourceDir)) continue;

    const sourcePath = await resolveExistingWithinRoot(sourceDir, file);
    if (!sourcePath) continue;

    const targetPath = path.join(targetDir, file);
    const parentRel = path.relative(targetDir, path.dirname(targetPath));
    if (!(await ensureDirWithinRoot(targetDir, parentRel))) continue;

    const existing = await lstat(targetPath).catch(() => null);
    if (existing?.isSymbolicLink()) continue;

    const sourceFile = Bun.file(sourcePath);
    if (!(await sourceFile.exists())) continue;

    await Bun.write(targetPath, sourceFile);
    log(`Copied: ${file}`);
  }
}

export async function symlinkDirs(
  sourceDir: string,
  targetDir: string,
  dirs: string[],
  log: (msg: string) => void,
): Promise<void> {
  for (const dir of dirs) {
    if (!isPathSafe(dir, sourceDir)) continue;

    const sourcePath = await resolveExistingWithinRoot(sourceDir, dir);
    if (!sourcePath) continue;

    const sourceStat = await stat(sourcePath).catch(() => null);
    if (!sourceStat?.isDirectory()) continue;

    const targetPath = path.join(targetDir, dir);
    const parentRel = path.relative(targetDir, path.dirname(targetPath));
    if (!(await ensureDirWithinRoot(targetDir, parentRel))) continue;

    const existing = await lstat(targetPath).catch(() => null);
    if (existing?.isSymbolicLink()) continue;

    await rm(targetPath, { recursive: true, force: true });
    await symlink(sourcePath, targetPath, "dir");
    log(`Symlinked: ${dir}`);
  }
}

export async function runHooks(
  cwd: string,
  commands: string[],
  log: (msg: string) => void,
): Promise<void> {
  for (const command of commands) {
    log(`Running hook: ${command}`);
    try {
      const shell = process.platform === "win32" ? ["cmd", "/c", command] : ["bash", "-c", command];
      const result = Bun.spawnSync(shell, { cwd, stderr: "pipe" });
      if (result.exitCode !== 0) {
        const stderr = result.stderr?.toString() ?? "";
        log(`Hook failed (exit ${result.exitCode}): ${command}${stderr ? ` — ${stderr.trim()}` : ""}`);
      }
    } catch (error) {
      log(`Hook error: ${error}`);
    }
  }
}