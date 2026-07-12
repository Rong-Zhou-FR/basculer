/** Shell escaping for cross-platform terminal launch scripts. */

const NULL_BYTE = /\x00/;

function assertShellSafe(value: string, context: string): void {
  if (NULL_BYTE.test(value)) {
    throw new Error(`${context} contains null bytes`);
  }
}

export function escapeBash(str: string): string {
  assertShellSafe(str, "Bash argument");
  return str
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\$/g, "\\$")
    .replace(/`/g, "\\`")
    .replace(/!/g, "\\!")
    .replace(/\n/g, " ")
    .replace(/\r/g, " ");
}

export function escapeBatch(str: string): string {
  assertShellSafe(str, "Batch argument");
  return str
    .replace(/%/g, "%%")
    .replace(/\^/g, "^^")
    .replace(/&/g, "^&")
    .replace(/</g, "^<")
    .replace(/>/g, "^>")
    .replace(/\|/g, "^|");
}

export function buildBashArgv(argv: string[]): string {
  return argv.map((arg) => `"${escapeBash(arg)}"`).join(" ");
}

export function buildBatchArgv(argv: string[]): string {
  return argv.map((arg) => `"${escapeBatch(arg).replace(/"/g, '""')}"`).join(" ");
}