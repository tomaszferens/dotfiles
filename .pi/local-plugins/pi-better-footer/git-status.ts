import { spawn } from "node:child_process";
import type { GitStatus } from "./types.js";

interface CachedGitStatus {
  staged: number;
  unstaged: number;
  untracked: number;
  timestamp: number;
}

interface CachedBranch {
  branch: string | null;
  timestamp: number;
}

interface CachedPrNumber {
  prNumber: string | null;
  forBranch: string | null;
  timestamp: number;
}

const CACHE_TTL_MS = 1000;
const BRANCH_TTL_MS = 500;
const PR_TTL_MS = 30000; // 30s — PR numbers don't change often
let cachedStatus: CachedGitStatus | null = null;
let cachedBranch: CachedBranch | null = null;
let cachedPr: CachedPrNumber | null = null;
let pendingFetch: Promise<void> | null = null;
let pendingBranchFetch: Promise<void> | null = null;
let pendingPrFetch: Promise<void> | null = null;
let invalidationCounter = 0;
let branchInvalidationCounter = 0;
let prInvalidationCounter = 0;

function parseGitStatusOutput(output: string): { staged: number; unstaged: number; untracked: number } {
  let staged = 0;
  let unstaged = 0;
  let untracked = 0;

  for (const line of output.split("\n")) {
    if (!line) continue;
    const x = line[0];
    const y = line[1];

    if (x === "?" && y === "?") {
      untracked++;
      continue;
    }

    if (x && x !== " " && x !== "?") {
      staged++;
    }

    if (y && y !== " ") {
      unstaged++;
    }
  }

  return { staged, unstaged, untracked };
}

function runGit(args: string[], timeoutMs = 200): Promise<string | null> {
  return new Promise((resolve) => {
    const proc = spawn("git", args, {
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let resolved = false;

    const finish = (result: string | null) => {
      if (resolved) return;
      resolved = true;
      clearTimeout(timeoutId);
      resolve(result);
    };

    proc.stdout.on("data", (data) => {
      stdout += data.toString();
    });

    proc.on("close", (code) => {
      finish(code === 0 ? stdout.trim() : null);
    });

    proc.on("error", () => {
      finish(null);
    });

    const timeoutId = setTimeout(() => {
      proc.kill();
      finish(null);
    }, timeoutMs);
  });
}

async function fetchGitBranch(): Promise<string | null> {
  const branch = await runGit(["branch", "--show-current"]);
  if (branch === null) return null;
  if (branch) return branch;

  const sha = await runGit(["rev-parse", "--short", "HEAD"]);
  return sha ? `${sha} (detached)` : "detached";
}

async function fetchGitStatus(): Promise<{ staged: number; unstaged: number; untracked: number } | null> {
  const output = await runGit(["status", "--porcelain"], 500);
  if (output === null) return null;
  return parseGitStatusOutput(output);
}

export function getCurrentBranch(providerBranch: string | null): string | null {
  const now = Date.now();

  if (cachedBranch && now - cachedBranch.timestamp < BRANCH_TTL_MS) {
    return cachedBranch.branch;
  }

  if (!pendingBranchFetch) {
    const fetchId = branchInvalidationCounter;
    pendingBranchFetch = fetchGitBranch().then((result) => {
      if (fetchId === branchInvalidationCounter) {
        cachedBranch = {
          branch: result,
          timestamp: Date.now(),
        };
      }
      pendingBranchFetch = null;
    });
  }

  return cachedBranch ? cachedBranch.branch : providerBranch;
}

async function fetchPrNumber(): Promise<string | null> {
  return new Promise((resolve) => {
    const proc = spawn("gh", ["pr", "view", "--json", "number", "-q", ".number"], {
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let resolved = false;

    const finish = (result: string | null) => {
      if (resolved) return;
      resolved = true;
      clearTimeout(timeoutId);
      resolve(result);
    };

    proc.stdout.on("data", (data: Buffer) => {
      stdout += data.toString();
    });

    proc.on("close", (code: number | null) => {
      const trimmed = stdout.trim();
      finish(code === 0 && /^\d+$/.test(trimmed) ? trimmed : null);
    });

    proc.on("error", () => {
      finish(null);
    });

    const timeoutId = setTimeout(() => {
      proc.kill();
      finish(null);
    }, 3000);
  });
}

export function getPrNumber(currentBranch: string | null): string | null {
  const now = Date.now();

  // If branch changed, invalidate PR cache
  if (cachedPr && cachedPr.forBranch !== currentBranch) {
    cachedPr = null;
  }

  if (cachedPr && now - cachedPr.timestamp < PR_TTL_MS) {
    return cachedPr.prNumber;
  }

  if (!pendingPrFetch) {
    const fetchId = prInvalidationCounter;
    pendingPrFetch = fetchPrNumber().then((result) => {
      if (fetchId === prInvalidationCounter) {
        cachedPr = {
          prNumber: result,
          forBranch: currentBranch,
          timestamp: Date.now(),
        };
      }
      pendingPrFetch = null;
    });
  }

  return cachedPr?.prNumber ?? null;
}

export function invalidateGitPr(): void {
  cachedPr = null;
  prInvalidationCounter++;
}

export function getGitStatus(providerBranch: string | null): GitStatus {
  const now = Date.now();
  const branch = getCurrentBranch(providerBranch);
  const prNumber = getPrNumber(branch);

  if (cachedStatus && now - cachedStatus.timestamp < CACHE_TTL_MS) {
    return { 
      branch,
      prNumber,
      staged: cachedStatus.staged,
      unstaged: cachedStatus.unstaged,
      untracked: cachedStatus.untracked,
    };
  }

  if (!pendingFetch) {
    const fetchId = invalidationCounter;
    pendingFetch = fetchGitStatus().then((result) => {
      if (fetchId === invalidationCounter) {
        cachedStatus = result
          ? { staged: result.staged, unstaged: result.unstaged, untracked: result.untracked, timestamp: Date.now() }
          : { staged: 0, unstaged: 0, untracked: 0, timestamp: Date.now() };
      }
      pendingFetch = null;
    });
  }

  if (cachedStatus) {
    return { 
      branch,
      prNumber,
      staged: cachedStatus.staged,
      unstaged: cachedStatus.unstaged,
      untracked: cachedStatus.untracked,
    };
  }

  return { branch, prNumber, staged: 0, unstaged: 0, untracked: 0 };
}

export function invalidateGitStatus(): void {
  cachedStatus = null;
  invalidationCounter++;
}

export function invalidateGitBranch(): void {
  cachedBranch = null;
  branchInvalidationCounter++;
}
