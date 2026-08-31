// ============================================================
// AirwayLab — AI Insights localStorage Cache
// Caches generated AI insights per night so reloading the page shows
// the existing result instead of silently re-generating (and, for
// community-tier users, burning another monthly credit).
// ============================================================

import type { Insight } from './insights';

const STORAGE_KEY = 'airwaylab_ai_insights';
const MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000; // 30 days, matches results persistence
const MAX_ENTRIES = 60; // cap growth — oldest entries pruned on save

export interface CachedAIInsights {
  insights: Insight[];
  isDeep: boolean;
  remainingCredits?: number;
  savedAt: number;
}

type CacheStore = Record<string, CachedAIInsights>;

function readStore(): CacheStore {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return {};
    const parsed: unknown = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? (parsed as CacheStore) : {};
  } catch {
    return {};
  }
}

function writeStore(store: CacheStore): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(store));
  } catch {
    // Best-effort — this is a convenience cache, not required data. A full
    // or unavailable localStorage just means insights regenerate on reload.
  }
}

/** Load cached AI insights for a night, if present and not expired. */
export function loadAIInsights(dateStr: string): CachedAIInsights | null {
  const store = readStore();
  const entry = store[dateStr];
  if (!entry) return null;
  if (Date.now() - entry.savedAt > MAX_AGE_MS) {
    delete store[dateStr];
    writeStore(store);
    return null;
  }
  return entry;
}

/** Save (or overwrite) cached AI insights for a night. */
export function saveAIInsights(
  dateStr: string,
  data: { insights: Insight[]; isDeep: boolean; remainingCredits?: number }
): void {
  const store = readStore();
  store[dateStr] = { ...data, savedAt: Date.now() };

  const keys = Object.keys(store);
  if (keys.length > MAX_ENTRIES) {
    const oldestFirst = keys.sort((a, b) => store[a]!.savedAt - store[b]!.savedAt);
    for (const key of oldestFirst.slice(0, keys.length - MAX_ENTRIES)) {
      delete store[key];
    }
  }

  writeStore(store);
}

/** Clear every cached AI insight. Used by the "clear local data" flow. */
export function clearAllAIInsights(): void {
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch {
    // Non-fatal — other local stores hold the bulk of the space.
  }
}
