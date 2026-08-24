"""Super-admin endpoints — the multi-school registry.

These run on the dedicated super-admin site (`sc_auth_is_super_site: 1` in its
site config), which has its own database separate from every school. The super
admin (that site's Administrator) registers schools — each school runs on its
own Frappe site/database — and manages each school's admin account + password.

  public_schools()                   → guest: selector list for the app
  schools()                          → all registered schools
  create_school(...)                 → register a school (+ admin account)
  update_school(...)                 → edit school profile fields
  reset_school_admin_password(...)   → set a new admin password
  delete_school(...)                 → unregister a school
"""

import os

import frappe
from frappe import _

from .auth import _resolve_role

BENCH_DIR = os.path.expanduser("~/Documents/frappe/frappe-bench")
BENCH_BIN = os.path.expanduser("~/.local/bin/bench")


def _require_super_admin():
    role = _resolve_role(frappe.session.user)
    if role != "Super Admin":
        frappe.throw(
            _("Only the super admin can manage schools."),
            frappe.PermissionError,
        )
    return role


def _shape_school(doc):
    return {
        "name": doc.name,
        "school_name": doc.school_name,
        "site": doc.site,
        "port": doc.port,
        "db_name": doc.db_name,
        "status": doc.status,
        "logo_url": doc.logo or None,
        "contact_email": doc.contact_email or None,
        "contact_number": doc.contact_number or None,
        "website": doc.website or None,
        "motto": doc.motto or None,
        "address": doc.address or None,
        "school_admin_name": doc.school_admin_name or None,
        "school_admin_email": doc.school_admin_email or None,
        "has_password": bool(doc.school_admin_password),
    }


@frappe.whitelist(allow_guest=True)
def public_schools():
    """Guest: name + connection info for every active school — the app's
    login screen uses this to let users pick which school to sign into."""
    schools = frappe.db.get_all(
        "School",
        filters={"status": "Active"},
        fields=["name", "school_name", "site", "port", "logo", "motto", "contact_email"],
        order_by="school_name",
    )
    return [
        {
            "name": s.name,
            "school_name": s.school_name,
            "site": s.site,
            "port": s.port,
            "logo_url": s.logo or None,
            "motto": s.motto or None,
            "contact_email": s.contact_email or None,
        }
        for s in schools
    ]


@frappe.whitelist()
def schools():
    """All registered schools (super admin only)."""
    _require_super_admin()
    docs = frappe.get_all("School", order_by="school_name")
    return [_shape_school(frappe.get_doc("School", d.name)) for d in docs]


@frappe.whitelist()
def create_school(
    school_name,
    site,
    port=8002,
    db_name=None,
    contact_email=None,
    contact_number=None,
    website=None,
    motto=None,
    address=None,
    school_admin_name=None,
    school_admin_email=None,
    school_admin_password=None,
):
    """Register a new school (super admin only). If the school's site already
    exists on this bench, its admin account is created there immediately."""
    _require_super_admin()
    if not school_name or not site:
        frappe.throw(_("School name and site are required."))
    if school_admin_email and not school_admin_password:
        frappe.throw(_("Admin password is required when an admin email is set."))

    doc = frappe.get_doc({
        "doctype": "School",
        "school_name": school_name,
        "site": site,
        "port": port,
        "db_name": db_name,
        "status": "Active",
        "contact_email": contact_email,
        "contact_number": contact_number,
        "website": website,
        "motto": motto,
        "address": address,
        "school_admin_name": school_admin_name,
        "school_admin_email": school_admin_email,
        "school_admin_password": school_admin_password,
    })
    doc.insert(ignore_permissions=True)

    apply_message = None
    if school_admin_email:
        apply_message = _apply_admin_to_site(doc)

    return {**_shape_school(doc), "provision_message": apply_message}


@frappe.whitelist()
def update_school(
    name,
    school_name=None,
    site=None,
    port=None,
    contact_email=None,
    contact_number=None,
    website=None,
    motto=None,
    address=None,
    school_admin_name=None,
    school_admin_email=None,
):
    """Edit a school's profile fields (super admin only)."""
    _require_super_admin()
    doc = frappe.get_doc("School", name)
    for field, value in [
        ("school_name", school_name),
        ("site", site),
        ("port", port),
        ("contact_email", contact_email),
        ("contact_number", contact_number),
        ("website", website),
        ("motto", motto),
        ("address", address),
        ("school_admin_name", school_admin_name),
        ("school_admin_email", school_admin_email),
    ]:
        if value is not None:
            doc.set(field, value)
    doc.save(ignore_permissions=True)
    return _shape_school(doc)


@frappe.whitelist()
def reset_school_admin_password(name, new_password):
    """Set a new school-admin password (super admin only). Applies on the
    school's own site when it exists, so the admin can log in immediately."""
    _require_super_admin()
    if not new_password or len(new_password) < 6:
        frappe.throw(_("Password must be at least 6 characters."))
    doc = frappe.get_doc("School", name)
    doc.school_admin_password = new_password
    doc.save(ignore_permissions=True)

    apply_message = None
    if doc.school_admin_email:
        apply_message = _apply_admin_to_site(doc)
    return {**_shape_school(doc), "provision_message": apply_message}


@frappe.whitelist()
def delete_school(name):
    """Unregister a school (super admin only). The school's own site/database
    is untouched — only the registry entry is removed."""
    _require_super_admin()
    frappe.delete_doc("School", name, force=True, ignore_permissions=True)
    return {"ok": True}


def provision_school_admin(school_admin_email, school_admin_name=None, password=None):
    """Run ON the school's own site (via `bench execute`) to create/update the
    school admin's User, the \"School Admin\" role, and their password. Returns
    \"APPLIED\" on success."""
    frappe.flags.ignore_email = True
    frappe.flags.ignore_permissions = True

    email = (school_admin_email or "").strip().lower()
    password = password or ""
    if not email or not password:
        return "No admin credentials"

    if not frappe.db.exists("Role", "School Admin"):
        frappe.get_doc({"doctype": "Role", "role_name": "School Admin"}).insert(
            ignore_permissions=True
        )

    name = (school_admin_name or "").strip()
    first = name.split(" ")[0] or email.split("@")[0]
    last = " ".join(name.split(" ")[1:]) or None

    if frappe.db.exists("User", email):
        u = frappe.get_doc("User", email)
    else:
        u = frappe.get_doc(
            {
                "doctype": "User",
                "email": email,
                "first_name": first,
                "last_name": last,
            }
        )
    u.new_password = password
    if "School Admin" not in {r.role for r in u.roles}:
        u.append("roles", {"role": "School Admin"})
    u.save(ignore_permissions=True)
    frappe.db.commit()
    return "APPLIED"


def _apply_admin_to_site(school):
    """Create/update the school admin's User + the \"School Admin\" role on the
    school's own site (its own database) via `bench execute`. Returns a short
    human-readable outcome, or None when the site is not provisioned yet."""
    if not school.site:
        return None
    from frappe.utils.password import get_decrypted_password

    try:
        password = get_decrypted_password("School", school.name, "school_admin_password")
    except Exception:
        password = ""

    if not school.school_admin_email or not password:
        return "No admin credentials set — nothing applied."

    import subprocess

    try:
        result = subprocess.run(
            [
                BENCH_BIN,
                "--site",
                school.site,
                "execute",
                "sc_auth.api.superadmin.provision_school_admin",
                school.school_admin_email,
                school.school_admin_name or "",
                password,
            ],
            cwd=BENCH_DIR,
            capture_output=True,
            text=True,
            timeout=240,
        )
        out = (result.stdout + result.stderr).strip()
        if result.returncode == 0 and "APPLIED" in out:
            return f"Admin account applied on {school.site} ✓"
        return f"Could not apply admin on {school.site}: {out[-400:]}"
    except Exception as e:  # noqa: BLE001
        return f"Could not apply admin on {school.site}: {e}"
