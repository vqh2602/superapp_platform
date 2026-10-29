const STORAGE_KEY = 'superapp_api_endpoint';
export const DEFAULT_ENDPOINT = 'https://superappplatfrom.alwaysdata.net';
export const LOCAL_ENDPOINT = 'http://localhost:3000';

export function normalizeEndpoint(url: string): string {
  let clean = (url || '').trim();
  if (!clean) return '';
  clean = clean.replace(/\/+$/, '');
  return clean;
}

export function getSavedEndpoint(): string {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved !== null) {
      return normalizeEndpoint(saved);
    }
  } catch {
    // ignore localStorage errors in sandboxed environments
  }
  return DEFAULT_ENDPOINT;
}

export function saveEndpoint(url: string): string {
  const normalized = normalizeEndpoint(url);
  try {
    localStorage.setItem(STORAGE_KEY, normalized);
  } catch {
    // ignore
  }
  return normalized;
}

export function buildApiUrl(subpath: string, customBase?: string): string {
  const base = customBase !== undefined ? normalizeEndpoint(customBase) : getSavedEndpoint();
  if (!base) {
    return subpath.startsWith('/') ? subpath : `/${subpath}`;
  }
  const cleanSubpath = subpath.startsWith('/') ? subpath : `/${subpath}`;
  if (base.endsWith('/api/v1') && cleanSubpath.startsWith('/api/v1')) {
    return `${base}${cleanSubpath.slice(7)}`;
  }
  return `${base}${cleanSubpath}`;
}

