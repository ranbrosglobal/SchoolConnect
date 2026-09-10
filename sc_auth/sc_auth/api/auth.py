"""Custom email/password authentication for the School Connect Flutter app.

Endpoints (all under /api/method/sc_auth.api.auth.*):

  POST login(email, password)                  → profile + sid + JWT
  POST signup_student(...)                     → creates User+Student+enrollment, auto-login
  GET  me()                                    → profile of the current session
  POST logout()                                → ends the Frappe session
  POST change_password(current, new)           → verifies + updates password

Login returns BOTH a real Frappe session sid (so the existing REST data calls
keep working with `Cookie: sid=...`) and a signed JWT (our own token) for the
app's bookkeeping.

The JWT secret lives in site config: `sc_auth_jwt_secret`.
"""

import datetime
import re

import frappe
import jwt as pyjwt
from frappe import _

JWT_ALGORITHM = "HS256"
JWT_TTL = datetime.timedelta(hours=12)
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _normalize_login(login):
    """Lowercase email-style logins (Frappe usernames are case-insensitive),
    but keep system logins like `Administrator` case-sensitive."""
    login = (login or "").strip()
    return login.lower() if "@" in login else login


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def _secret():
    """JWT signing secret (site config). Dev fallback with a loud marker."""
    return frappe.conf.get("sc_auth_jwt_secret") or "dev-only-sc-auth-secret-change-me"


def _make_token(email):
    now = datetime.datetime.now(datetime.timezone.utc)
    return pyjwt.encode(
        {"sub": email, "iat": now, "exp": now + JWT_TTL},
        _secret(),
        algorithm=JWT_ALGORITHM,
    )


def _jwt_user():
    """Email from a valid `Authorization: Bearer <jwt>` header, or None."""
    auth = frappe.get_request_header("Authorization") or ""
    if not auth.startswith("Bearer "):
        return None
    token = auth[7:].strip()
    try:
        payload = pyjwt.decode(token, _secret(), algorithms=[JWT_ALGORITHM])
    except Exception:
        return None
    email = payload.get("sub")
    if not email or not frappe.db.exists("User", email):
        return None
    return email


def before_request():
    """Session-free (web/mobile) auth: when the request has no Frappe session
    but carries a valid sc_auth JWT, act as that user for this request.
    Lets the app authenticate with `Authorization: Bearer <jwt>` instead of
    the `Cookie: sid=...` header (which browsers strip on web)."""
    if frappe.session.user == "Guest":
        email = _jwt_user()
        if email:
            # Mirror frappe.set_user() but WITHOUT wiping frappe.local.form_dict
            # (set_user resets it, which would drop the request's POST body /
            # query params before the handler runs).
            frappe.local.session.user = email
            frappe.local.session.sid = email
            frappe.local.session.data = frappe._dict()
            frappe.local.role_permissions = {}
            frappe.local.cache = {}


def _resolve_role(email):
    """Map a user to the app role.

    Super Admin — any system user of the dedicated super-admin site (its own
    database), identified by `sc_auth_is_super_site` in the site config. The
    super site hosts only the registry, so its System Manager users are the
    super admins.
    School Admin — a user with the "School Admin" role on a school site.
    System Manager / Instructor / Student — the usual education roles.
    """
    if email == "Administrator":
        return "Super Admin" if frappe.conf.get("sc_auth_is_super_site") else "System Manager"
    user = frappe.get_doc("User", email)
    roles = {r.role for r in user.roles}
    if frappe.conf.get("sc_auth_is_super_site"):
        return "Super Admin" if "System Manager" in roles else "System Manager"
    if "School Admin" in roles:
        return "School Admin"
    if "System Manager" in roles:
        return "System Manager"
    if "Academics User" in roles or "Instructor" in roles:
        return "Instructor"
    if "Student" in roles or frappe.db.exists("Student", {"user": email}):
        return "Student"
    return "System Manager"  # any other enabled System User is treated as admin


def _profile(email):
    """The payload the Flutter app turns into its UserModel."""
    user = frappe.get_doc("User", email)
    role = _resolve_role(email)
    profile = {
        "name": email,
        "email": email,
        "full_name": user.full_name or user.first_name or email,
        "role": role,
        "is_super_admin": role == "Super Admin",
        "token": _make_token(email),
    }
    if role == "Student":
        student = frappe.db.get_value("Student", {"user": email}, "name")
        if student:
            profile["student_id"] = student
            groups = frappe.get_all(
                "Student Group Student",
                filters={"student": student, "active": 1},
                pluck="parent",
            )
            profile["student_groups"] = groups or None
    elif role == "Instructor":
        instr = frappe.db.get_value(
            "Instructor", {"instructor_name": user.full_name}, "name"
        )
        if instr:
            profile["instructor_id"] = instr
    return profile


def _current_academic_year():
    today = str(datetime.date.today())
    ay = frappe.db.get_value(
        "Academic Year",
        {"year_start_date": ("<=", today), "year_end_date": (">=", today)},
        "name",
    )
    return ay or frappe.db.get_value("Academic Year", {}, "name", order_by="creation asc")


def _enroll(student, student_name, program):
    if not program or not frappe.db.exists("Program", program):
        return
    if frappe.db.exists("Program Enrollment", {"student": student, "program": program}):
        return
    courses = [
        c.course for c in frappe.get_doc("Program", program).courses
    ]
    frappe.get_doc(
        {
            "doctype": "Program Enrollment",
            "student": student,
            "student_name": student_name,
            "enrollment_date": str(datetime.date.today()),
            "program": program,
            "academic_year": _current_academic_year(),
            "courses": [{"course": c} for c in courses],
        }
    ).insert(ignore_permissions=True)


def _start_session(email, password):
    """Validate credentials and establish a real Frappe session."""
    lm = frappe.auth.LoginManager()
    lm.authenticate(user=email, pwd=password)  # raises AuthenticationError
    lm.post_login()  # creates the session + queues the sid cookie
    return lm


# --------------------------------------------------------------------------
# endpoints
# --------------------------------------------------------------------------
@frappe.whitelist(allow_guest=True)
def login(email, password):
    if not (email and password):
        frappe.throw(_("Email and password are required"), frappe.AuthenticationError)

    _start_session(_normalize_login(email), password)

    profile = _profile(frappe.session.user)
    profile["sid"] = frappe.session.sid
    return profile


@frappe.whitelist(allow_guest=True)
def signup_student(
    full_name,
    email,
    password,
    gender=None,
    date_of_birth=None,
    student_group=None,
    program=None,
    city=None,
    state=None,
    country=None,
):
    """Self-registration: creates the User + Student + program enrollment and
    logs the new student in."""
    full_name = (full_name or "").strip()
    email = (email or "").strip().lower()

    if not (full_name and email and password):
        frappe.throw(_("Name, email and password are required"))
    if len(password) < 8:
        frappe.throw(_("Password must be at least 8 characters long"))
    if not EMAIL_RE.match(email):
        frappe.throw(_("Please enter a valid email address"))
    if frappe.db.exists("User", email):
        frappe.throw(_("An account with this email already exists. Try logging in."))

    # System-record creation (User, Student + education's auto-created
    # Customer) must run with elevated rights; rule enforcement is our own
    # validations above. Restore the guest context afterwards.
    original_user = frappe.session.user
    frappe.set_user("Administrator")
    try:
        parts = full_name.split()
        first, last = parts[0], " ".join(parts[1:]) or None

        # User
        frappe.get_doc(
            {
                "doctype": "User",
                "email": email,
                "first_name": first,
                "last_name": last,
                "full_name": full_name,
                "user_type": "System User",
                "enabled": 1,
                "roles": [{"role": "Student"}],
            }
        ).insert(ignore_permissions=True)
        frappe.utils.password.update_password(email, password)

        # Student
        student = frappe.get_doc(
            {
                "doctype": "Student",
                "first_name": first,
                "last_name": last,
                "student_email_id": email,
                "user": email,
                "gender": gender or "Other",
                "date_of_birth": date_of_birth or None,
                "city": city or None,
                "state": state or None,
                "country": country or None,
                "enabled": 1,
            }
        )
        student.insert(ignore_permissions=True)

        # Class membership + program enrollment
        group = None
        if student_group:
            group = frappe.db.get_value(
                "Student Group", {"student_group_name": student_group}, "name"
            )
        if group:
            sg = frappe.get_doc("Student Group", group)
            if not any(r.student == student.name for r in sg.students):
                sg.append(
                    "students",
                    {"student": student.name, "student_name": full_name, "active": 1},
                )
                sg.save(ignore_permissions=True)
        if not program and group:
            program = frappe.get_doc("Student Group", group).program
        _enroll(student.name, full_name, program)

        frappe.db.commit()
    finally:
        frappe.set_user(original_user)

    # auto-login
    _start_session(email, password)
    profile = _profile(frappe.session.user)
    profile["sid"] = frappe.session.sid
    return profile


@frappe.whitelist()
def me():
    email = frappe.session.user
    if not email or email == "Guest":
        frappe.throw(_("Session expired. Please login again."), frappe.AuthenticationError)
    return _profile(email)


@frappe.whitelist()
def logout():
    frappe.local.login_manager.logout()
    frappe.db.commit()
    return {"message": "Logged out"}


@frappe.whitelist()
def change_password(current_password, new_password):
    email = frappe.session.user
    if email == "Guest" or not email:
        frappe.throw(_("Session expired. Please login again."), frappe.AuthenticationError)
    if not current_password or not new_password:
        frappe.throw(_("Both current and new passwords are required"))
    if len(new_password) < 8:
        frappe.throw(_("New password must be at least 8 characters long"))
    if current_password == new_password:
        frappe.throw(_("New password must be different from the current one"))

    frappe.utils.password.check_password(email, current_password)  # raises if wrong
    frappe.utils.password.update_password(email, new_password)
    frappe.db.commit()
    return {"message": "Password updated successfully"}
