/*
 * localStorage keys — namespaced per console so the School Admin console and
 * the Super Admin console never collide (each has its own session, mock DB
 * and CSRF token).
 */
export const SESSION_KEY = 'sc_schooladmin_session'
export const DB_KEY = 'sc_schooladmin_db_v1'
export const CSRF_KEY = 'sc_schooladmin_csrf_token'

// Keys used by older builds, when both consoles shared one storage namespace.
// The session is deliberately NOT migrated: after the console became School
// Admin only, any persisted session (possibly a super admin) must be dropped
// so the user signs in again. All leftovers are removed on boot (see mock.js).
export const LEGACY_DB_KEY = 'sc_mock_db_v1'
export const LEGACY_SESSION_KEY = 'sc_admin_session'
export const LEGACY_CSRF_KEY = 'sc_csrf_token'
