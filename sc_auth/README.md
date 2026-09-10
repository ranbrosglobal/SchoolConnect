# sc_auth — School Connect custom authentication

Custom email/password auth (login + signup) for the School Connect Flutter app,
installed on top of Frappe Education.

Endpoints: `/api/method/sc_auth.api.auth.{login, signup_student, me, logout, change_password}`

JWT signing key: site config `sc_auth_jwt_secret` (set via `bench --site <site> set-config sc_auth_jwt_secret <value>`).
