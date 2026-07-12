import { mkdir, unlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import * as path from "node:path";
import { getDefaultWorktreeBase } from "./config";
import { getProjectId } from "./project-id";

type Shell = (strings: TemplateStringsArray, ...values: unknown[]) => {
  text: () => Promise<string>;
  quiet: () => Promise<void>;
};

type Result<T> = { ok: true; value: T } | { ok: false; error: string };

function ok<T>(value: T): Result<T> {
  return { ok: true, value };
}

function err<T>(error: string): Result<T> {
  return { ok: false, error };
}

async function gitSpawn(args: string[], cwd: string): Promise<Result<string>> {
  try {
    const proc = Bun.spawn(["git", ...args], { cwd, stdout: "pipe", stderr: "pipe" });
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(proc.stdout).text(),
      new Response(proc.stderr).text(),
      proc.exited,
    ]);
    if (exitCode !== 0) return err(stderr.trim() || `git ${args[0]} failed`);
    return ok(stdout.trim());
  } catch (error) {
    return err(error instanceof Error ? error.message : String(error));
  }
}

export async function getWorktreePath(
  projectRoot: string,
  branch: string,
  basePath?: string,
): Promise<string> {
  const projectId = await getProjectId(projectRoot);
  return path.join(basePath ?? getDefaultWorktreeBase(), projectId, branch);
}

export async function branchExists(cwd: string, branch: string): Promise<boolean> {
  const result = await gitSpawn(["rev-parse", "--verify", branch], cwd);
  return result.ok;
}

export async function createWorktree(
  repoRoot: string,
  branch: string,
  baseBranch?: string,
  basePath?: string,
): Promise<Result<string>> {
  const worktreePath = await getWorktreePath(repoRoot, branch, basePath);
  await mkdir(path.dirname(worktreePath), { recursive: true });

  const exists = await branchExists(repoRoot, branch);
  if (exists) {
    const result = await gitSpawn(["worktree", "add", worktreePath, branch], repoRoot);
    return result.ok ? ok(worktreePath) : result;
  }

  const base = baseBranch ?? "HEAD";
  const result = await gitSpawn(["worktree", "add", "-b", branch, worktreePath, base], repoRoot);
  return result.ok ? ok(worktreePath) : result;
}

export async function removeWorktree(repoRoot: string, worktreePath: string): Promise<Result<void>> {
  const result = await gitSpawn(["worktree", "remove", "--force", worktreePath], repoRoot);
  return result.ok ? ok(undefined) : err(result.error);
}

export async function listWorktrees(repoRoot: string): Promise<string> {
  const result = await gitSpawn(["worktree", "list", "--porcelain"], repoRoot);
  return result.ok ? result.value : result.error;
}

export async function quietCommit(
  $: Shell,
  worktreePath: string,
  message: string,
): Promise<Result<string>> {
  const msgPath = path.join(tmpdir(), `oc-wt-commit-${Date.now()}.txt`);
  try {
    await writeFile(msgPath, message, "utf8");
    await $`git -c advice.convertCRLF=false -C ${worktreePath} add -A`.quiet();
    await $`git -c advice.convertCRLF=false -C ${worktreePath} commit -F ${msgPath} -q --allow-empty`.quiet();
    const hash = (await $`git -C ${worktreePath} rev-parse --short HEAD`.text()).trim();
    return ok(hash);
  } catch (error) {
    return err(error instanceof Error ? error.message : String(error));
  } finally {
    await unlink(msgPath).catch(() => {});
  }
}