/*
 * localStorage keys — namespaced per console so the Super Admin console and
 * the School Admin console never collide (each has its own session, mock DB
 * and CSRF token).
 */
export const SESSION_KEY = 'sc_superadmin_session'
export const DB_KEY = 'sc_superadmin_db_v1'
export const CSRF_KEY = 'sc_superadmin_csrf_token'

// Keys used by older builds, when both consoles shared one storage namespace.
// Nothing is adopted from them — this console has its own mock DB and the
// user signs in again — so all leftovers are removed on boot (see mock.js).
export const LEGACY_SESSION_KEY = 'sc_admin_session'
export const LEGACY_DB_KEY = 'sc_mock_db_v1'
export const LEGACY_CSRF_KEY = 'sc_csrf_token'
