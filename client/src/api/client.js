const TOKEN_KEY = 'krishichain.token';

export const tokenStore = {
  get: () => localStorage.getItem(TOKEN_KEY),
  set: (token) => localStorage.setItem(TOKEN_KEY, token),
  clear: () => localStorage.removeItem(TOKEN_KEY),
};

/**
 * Thin fetch wrapper. Attaches the bearer token, parses JSON, and turns
 * a non-2xx response into a thrown Error carrying the server's own
 * message — the API already translates Oracle constraint violations into
 * readable text (see server/src/services/auth.service.js), so there is
 * nothing to reword here.
 */
export async function api(path, { method = 'GET', body, auth = true } = {}) {
  const headers = {};
  if (body) headers['Content-Type'] = 'application/json';

  const token = tokenStore.get();
  if (auth && token) headers.Authorization = `Bearer ${token}`;

  let response;
  try {
    response = await fetch(`/api${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new Error('Cannot reach the KrishiChain server. Check that the API is running.');
  }

  const text = await response.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      // A proxy or infrastructure error may be HTML/plain text. Preserve the
      // useful HTTP status instead of replacing it with a JSON.parse error.
    }
  }

  if (!response.ok) {
    throw new Error(data?.error || `Request failed (${response.status})`);
  }
  return data;
}
