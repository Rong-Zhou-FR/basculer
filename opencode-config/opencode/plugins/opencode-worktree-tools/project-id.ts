import * as crypto from "node:crypto";
import { stat } from "node:fs/promises";
import * as path from "node:path";

function hashPath(projectRoot: string): string {
  return crypto.createHash("sha256").update(projectRoot).digest("hex").slice(0, 16);
}

export async function getProjectId(projectRoot: string): Promise<string> {
  if (!projectRoot) throw new Error("projectRoot is required");

  const gitPath = path.join(projectRoot, ".git");
  const gitStat = await stat(gitPath).catch(() => null);
  if (!gitStat) return hashPath(projectRoot);

  let gitDir = gitPath;

  if (gitStat.isFile()) {
    const content = await Bun.file(gitPath).text();
    const match = content.match(/^gitdir:\s*(.+)$/m);
    if (!match) throw new Error(`Invalid .git file at ${gitPath}`);

    const resolvedGitdir = path.resolve(projectRoot, match[1].trim());
    const commondirPath = path.join(resolvedGitdir, "commondir");
    const commondirFile = Bun.file(commondirPath);

    if (await commondirFile.exists()) {
      gitDir = path.resolve(resolvedGitdir, (await commondirFile.text()).trim());
    } else {
      gitDir = path.resolve(resolvedGitdir, "../..");
    }
  }

  const cacheFile = path.join(gitDir, "opencode");
  const cache = Bun.file(cacheFile);
  if (await cache.exists()) {
    const cached = (await cache.text()).trim();
    if (/^[a-f0-9]{40}$/i.test(cached) || /^[a-f0-9]{16}$/i.test(cached)) {
      return cached;
    }
  }

  try {
    const proc = Bun.spawn(["git", "rev-list", "--max-parents=0", "--all"], {
      cwd: projectRoot,
      stdout: "pipe",
      stderr: "pipe",
    });
    const exitCode = await proc.exited;
    if (exitCode === 0) {
      const roots = (await new Response(proc.stdout).text())
        .split("\n")
        .map((x) => x.trim())
        .filter(Boolean)
        .sort();
      if (roots[0] && /^[a-f0-9]{40}$/i.test(roots[0])) {
        try {
          await Bun.write(cacheFile, roots[0]);
        } catch {
          // cache write is best-effort
        }
        return roots[0];
      }
    }
  } catch {
    // fall through to path hash
  }

  return hashPath(projectRoot);
}