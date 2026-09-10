import frappe
from frappe import _
import json


@frappe.whitelist(allow_guest=True)
def login(usr, pwd):
    """
    Custom login endpoint for Flutter app.
    Returns user info and role after successful login.
    """
    try:
        # Use Frappe's built-in login manager
        from frappe.utils.password import check_password

        # Authenticate user
        user = frappe.get_doc("User", usr)
        if not user or user.disabled:
            frappe.throw(_("Invalid credentials or user is disabled"))

        # Check password
        check_password(user.name, pwd)

        # Create session
        frappe.local.login_manager.login_as(user.name)

        # Get user roles
        roles = [r.role for r in user.roles]

        # Determine primary role for Flutter routing
        primary_role = "Student"  # default
        if "System Manager" in roles or "Administrator" in roles:
            primary_role = "System Manager"
        elif "School Admin" in roles:
            primary_role = "School Admin"
        elif "Instructor" in roles:
            primary_role = "Instructor"
        elif "Student" in roles:
            primary_role = "Student"

        # Get additional user info
        user_info = {
            "token": frappe.session.user,
            "email": user.email,
            "full_name": user.full_name or user.first_name,
            "role": primary_role,
            "roles": roles,
            "name": user.name,
        }

        # Get linked student or instructor info
        if primary_role == "Student":
            student = frappe.get_all(
                "Student",
                filters={"student_email_id": user.email},
                fields=["name", "school", "school_name", "student_group"],
                limit=1,
            )
            if student:
                user_info["student_id"] = student[0].name
                user_info["school"] = student[0].school
                user_info["school_name"] = student[0].school_name
                user_info["student_group"] = student[0].student_group

        elif primary_role == "Instructor":
            instructor = frappe.get_all(
                "Instructor",
                filters={"instructor_email": user.email},
                fields=["name", "school"],
                limit=1,
            )
            if instructor:
                user_info["instructor_id"] = instructor[0].name
                user_info["school"] = instructor[0].school

        elif primary_role == "School Admin":
            # School Admins are linked to a school via the 'School' custom field on User
            if frappe.db.has_column("User", "custom_school"):
                school = frappe.db.get_value(
                    "User", user.name, "custom_school"
                )
                if school:
                    user_info["school"] = school
                    user_info["school_name"] = frappe.db.get_value(
                        "School", school, "school_name"
                    )

        return user_info

    except frappe.AuthenticationError:
        frappe.throw(_("Invalid email or password"))
    except Exception as e:
        frappe.log_error(frappe.get_traceback(), "Login Error")
        frappe.throw(_("Login failed: {0}").format(str(e)))


@frappe.whitelist()
def logout():
    """
    End the current session.
    The web consoles call school_connect.api.auth.logout in live mode; Frappe's
    global logout lives at /api/method/logout, so this is the app-shaped alias.
    """
    try:
        frappe.local.login_manager.logout()
    except Exception:
        # session may already be gone — logout is best-effort
        pass
    return {"message": "Logged out"}


@frappe.whitelist(allow_guest=True)
def signup_student(
    full_name,
    email,
    password,
    school,
    age=None,
    gender=None,
    city=None,
    state=None,
    country=None,
    student_group=None,
):
    """
    Custom signup endpoint for students.
    Creates User and Student documents in one transaction.
    """
    try:
        # Check if user already exists
        if frappe.db.exists("User", email):
            frappe.throw(_("User with this email already exists"))

        # Validate school exists
        if not frappe.db.exists("School", school):
            frappe.throw(_("Invalid school selected"))

        # Start transaction
        frappe.db.begin()

        # Create User
        user = frappe.get_doc(
            {
                "doctype": "User",
                "email": email,
                "first_name": full_name.split()[0] if full_name else "",
                "last_name": " ".join(full_name.split()[1:]) if len(full_name.split()) > 1 else "",
                "full_name": full_name,
                "send_welcome_email": 0,
                "user_type": "Website User",
            }
        )
        user.insert(ignore_permissions=True)

        # Set password
        user.new_password = password
        user.save(ignore_permissions=True)

        # Add Student role
        user.append("roles", {"role": "Student"})
        user.save(ignore_permissions=True)

        # Create Student document
        student = frappe.get_doc(
            {
                "doctype": "Student",
                "student_name": full_name,
                "student_email_id": email,
                "school": school,
                "gender": gender,
                "date_of_birth": None,  # Can be calculated from age if needed
            }
        )

        # Add custom fields if they exist
        if age:
            student.age = int(age)
        if city:
            student.city = city
        if state:
            student.state = state
        if country:
            student.country = country

        student.insert(ignore_permissions=True)

        # Link student to user
        student.user = user.name
        student.save(ignore_permissions=True)

        # If student group provided, add to group
        if student_group:
            sg_student = frappe.get_doc(
                {
                    "doctype": "Student Group Student",
                    "parent": student_group,
                    "student": student.name,
                }
            )
            sg_student.insert(ignore_permissions=True)

        frappe.db.commit()

        return {
            "message": "Student account created successfully",
            "user": user.name,
            "student": student.name,
        }

    except Exception as e:
        frappe.db.rollback()
        frappe.log_error(frappe.get_traceback(), "Signup Error")
        frappe.throw(_("Signup failed: {0}").format(str(e)))


@frappe.whitelist(allow_guest=True)
def search_schools(state=None, city=None, q=None):
    """
    Search schools by state, city, or query.
    Used during student signup.
    """
    filters = {"disabled": 0}

    if state:
        filters["state"] = state
    if city:
        filters["city"] = city

    schools = frappe.get_all(
        "School",
        filters=filters,
        fields=["name", "school_name", "city", "state", "country", "address"],
        limit=50,
    )

    # Filter by query if provided
    if q:
        q = q.lower()
        schools = [
            s
            for s in schools
            if q in s.get("school_name", "").lower()
            or q in s.get("city", "").lower()
            or q in s.get("state", "").lower()
        ]

    return schools


@frappe.whitelist()
def update_profile(full_name=None):
    """
    Update the logged-in user's profile (currently just the full name).
    Used by the web admin Settings page.
    """
    user = frappe.get_doc("User", frappe.session.user)

    if full_name:
        full_name = full_name.strip()
        if len(full_name) < 2:
            frappe.throw(_("Name must be at least 2 characters long"))
        parts = full_name.split()
        user.first_name = parts[0]
        user.last_name = " ".join(parts[1:]) if len(parts) > 1 else ""
        user.full_name = full_name
        user.save(ignore_permissions=True)

    return {
        "name": user.name,
        "email": user.email,
        "full_name": user.full_name or user.first_name,
    }


@frappe.whitelist()
def change_password(current_password, new_password):
    """
    Change the logged-in user's password after verifying the current one.
    Used by the web admin Settings page.
    """
    from frappe.utils.password import check_password

    try:
        check_password(frappe.session.user, current_password)
    except frappe.AuthenticationError:
        frappe.throw(_("Current password is incorrect"))

    if not new_password or len(new_password) < 6:
        frappe.throw(_("New password must be at least 6 characters long"))
    if new_password == current_password:
        frappe.throw(_("New password must be different from the current password"))

    frappe.local.login_manager.update_password(frappe.session.user, new_password)
    return {"message": "Password updated successfully"}


@frappe.whitelist()
def get_schools_classes(school):
    """
    Get classes (Student Groups) for a school.
    Used during student signup for class selection.
    """
    # Get programs for this school
    programs = frappe.get_all(
        "Program",
        filters={"school": school},
        fields=["name", "program_name"],
    )

    # Get student groups
    classes = frappe.get_all(
        "Student Group",
        filters={"school": school, "active": 1},
        fields=[
            "name",
            "student_group_name",
            "program",
            "program_name",
            "course",
            "course_name",
        ],
    )

    return {
        "programs": programs,
        "classes": classes,
    }
