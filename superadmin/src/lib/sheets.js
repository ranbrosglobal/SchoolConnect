/**
 * Google Sheets API client for browser.
 *
 * Replaces the Frappe/sc_backend HTTP backend with direct Google Sheets API
 * calls using the signed-in user's own Google OAuth token.
 *
 * Flow: Google Sign-In → access token → Sheets API v4 → spreadsheet tabs
 * No server, no Docker, no Frappe.
 */

let accessToken = null;
let spreadsheetId = null;

/**
 * Initialize with a spreadsheet ID (set after Google Sign-In).
 */
export function configure(spreadsheetId_, accessToken_) {
  accessToken = accessToken_;
  spreadsheetId = spreadsheetId_;
}

export function getAccessToken() {
  return accessToken;
}

export function getSpreadsheetId() {
  return spreadsheetId;
}

// ─── Google Sign-In (Identity Services) ───────────────────────────────

const SCOPES = 'https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive.file email profile';
const CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID || '';

let tokenClient = null;
let resolveSignIn = null;

/**
 * Initialize Google Identity Services (GIS) token client.
 * Call once on app boot.
 */
export function initGoogleAuth() {
  return new Promise((resolve) => {
    const interval = setInterval(() => {
      if (window.google?.accounts?.oauth2) {
        clearInterval(interval);

        tokenClient = window.google.accounts.oauth2.initTokenClient({
          client_id: CLIENT_ID,
          scope: SCOPES,
          callback: (tokenResponse) => {
            accessToken = tokenResponse.access_token;
            if (resolveSignIn) {
              resolveSignIn(accessToken);
              resolveSignIn = null;
            }
          },
        });

        resolve();
      }
    }, 100);

    // Load GIS script if not already present
    if (!document.querySelector('script[src*="accounts.google.com/gsi/client"]')) {
      const script = document.createElement('script');
      script.src = 'https://accounts.google.com/gsi/client';
      script.async = true;
      script.defer = true;
      document.head.appendChild(script);
    }
  });
}

/**
 * Trigger Google Sign-In. Returns a promise that resolves with the access token.
 */
export function signInWithGoogle() {
  return new Promise((resolve, reject) => {
    if (!tokenClient) {
      reject(new Error('Google auth not initialized. Call initGoogleAuth() first.'));
      return;
    }
    resolveSignIn = resolve;
    tokenClient.requestAccessToken();
  });
}

/**
 * Sign out (revoke token).
 */
export function signOutGoogle() {
  if (accessToken && window.google?.accounts?.oauth2) {
    window.google.accounts.oauth2.revoke(accessToken);
  }
  accessToken = null;
}

// ─── Sheets API helpers ──────────────────────────────────────────────

const SHEETS_BASE = 'https://sheets.googleapis.com/v4/spreadsheets';

async function sheetsRequest(method, path, body = null) {
  if (!accessToken) throw new Error('Not authenticated — sign in with Google first.');
  if (!spreadsheetId) throw new Error('No spreadsheet configured.');

  const url = `${SHEETS_BASE}/${spreadsheetId}${path}`;
  const opts = {
    method,
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
  };
  if (body) opts.body = JSON.stringify(body);

  const res = await fetch(url, opts);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error?.message || `Sheets API error ${res.status}`);
  }
  return res.json();
}

/**
 * Read all rows from a tab. Returns array of objects keyed by header row.
 */
export async function readTab(tabName) {
  const data = await sheetsRequest('GET', `/values/${tabName}!A:ZZ`);
  const values = data.values;
  if (!values || values.length < 2) return [];

  const headers = values[0].map(h => String(h));
  const rows = [];
  for (let i = 1; i < values.length; i++) {
    const row = {};
    for (let j = 0; j < headers.length; j++) {
      row[headers[j]] = j < values[i].length ? String(values[i][j]) : '';
    }
    rows.push(row);
  }
  return rows;
}

/**
 * Find one row matching a field value.
 */
export async function findOne(tabName, field, value) {
  const rows = await readTab(tabName);
  return rows.find(r => r[field] === value) || null;
}

/**
 * Find rows matching a field value.
 */
export async function findMany(tabName, field, value) {
  const rows = await readTab(tabName);
  return rows.filter(r => r[field] === value);
}

/**
 * Append a row to a tab.
 */
export async function appendRow(tabName, values) {
  return sheetsRequest('POST', `/values/${tabName}!A:ZZ:append?valueInputOption=USER_ENTERED`, {
    values: [values],
  });
}

/**
 * Update a single cell in a tab.
 */
export async function updateCell(tabName, range, value) {
  return sheetsRequest('PUT', `/values/${tabName}!${range}?valueInputOption=USER_ENTERED`, {
    values: [[value]],
  });
}

/**
 * Update rows matching a condition.
 */
export async function updateWhere(tabName, matchField, matchValue, updates) {
  const response = await sheetsRequest('GET', `/values/${tabName}!A:ZZ`);
  const values = response.values;
  if (!values || values.length < 2) return;

  const headers = values[0].map(h => String(h));
  for (let i = 1; i < values.length; i++) {
    const fieldIdx = headers.indexOf(matchField);
    if (fieldIdx === -1) continue;
    const cellValue = i < values.length && fieldIdx < values[i].length ? String(values[i][fieldIdx]) : '';
    if (cellValue === matchValue) {
      for (const [field, val] of Object.entries(updates)) {
        const colIdx = headers.indexOf(field);
        if (colIdx !== -1) {
          const range = `${String.fromCharCode(65 + colIdx)}${i + 1}`;
          await updateCell(tabName, range, val);
        }
      }
      return;
    }
  }
}

/**
 * Delete a row by clearing its contents.
 */
export async function deleteWhere(tabName, matchField, matchValue) {
  const response = await sheetsRequest('GET', `/values/${tabName}!A:ZZ`);
  const values = response.values;
  if (!values || values.length < 2) return;

  const headers = values[0].map(h => String(h));
  for (let i = 1; i < values.length; i++) {
    const fieldIdx = headers.indexOf(matchField);
    if (fieldIdx === -1) continue;
    const cellValue = i < values.length && fieldIdx < values[i].length ? String(values[i][fieldIdx]) : '';
    if (cellValue === matchValue) {
      const emptyRow = headers.map(() => '');
      const lastCol = String.fromCharCode(64 + headers.length);
      await updateCell(tabName, `A${i + 1}:${lastCol}${i + 1}`, emptyRow.join(','));
      return;
    }
  }
}

/**
 * Generate a unique ID.
 */
export function genId(prefix = '') {
  return `${prefix}${Date.now().toString(36)}`;
}

export default {
  configure,
  getAccessToken,
  getSpreadsheetId,
  initGoogleAuth,
  signInWithGoogle,
  signOutGoogle,
  readTab,
  findOne,
  findMany,
  appendRow,
  updateCell,
  updateWhere,
  deleteWhere,
  genId,
};
