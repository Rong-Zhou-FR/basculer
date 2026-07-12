import * as path from "node:path";

/** Branch name validation — blocks invalid git refs and shell metacharacters. */

const INVALID_REF = /[~^:?*[\]\\;&|`$()]/;

export function validateBranchName(name: string): string | null {
  if (!name || !name.trim()) return "Branch name cannot be empty";
  if (name.length > 255) return "Branch name too long (max 255)";
  if (name.startsWith("-")) return "Branch name cannot start with '-'";
  if (name.startsWith("/") || name.endsWith("/")) return "Branch name cannot start or end with '/'";
  if (name.includes("//")) return "Branch name cannot contain '//'";
  if (name.includes("@{")) return "Branch name cannot contain '@{'";
  if (name.includes("..")) return "Branch name cannot contain '..'";
  if (name.startsWith(".") || name.endsWith(".")) return "Branch name cannot start or end with '.'";
  if (name.endsWith(".lock")) return "Branch name cannot end with '.lock'";

  for (let i = 0; i < name.length; i++) {
    const code = name.charCodeAt(i);
    if (code <= 0x1f || code === 0x7f) return "Branch name contains control characters";
  }

  if (INVALID_REF.test(name) || /[\x00-\x1f\x7f ~^:?*[\]\\]/.test(name)) {
    return "Branch name contains invalid characters";
  }

  return null;
}

export function isPathSafe(relativePath: string, baseDir: string): boolean {
  if (path.isAbsolute(relativePath)) return false;
  if (relativePath.includes("..")) return false;
  const resolved = path.resolve(baseDir, relativePath);
  return resolved.startsWith(baseDir + path.sep) || resolved === baseDir;
}