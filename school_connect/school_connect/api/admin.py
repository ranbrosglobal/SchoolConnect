import frappe
from frappe import _

from school_connect.timetable import (
    TIMETABLE_DAYS,
    get_school_periods,
    normalize_periods,
)


def _get_admin_school():
    """
    Determine the school the current admin manages.

    - System Manager / Administrator: access to all schools (returns None)
    - School Admin: returns their linked school (from User.custom_school)
    - Anyone else: permission denied
    """
    roles = frappe.get_roles(frappe.session.user)

    if "System Manager" in roles or "Administrator" in roles:
        return None

    if "School Admin" in roles:
        school = None
        if frappe.db.has_column("User", "custom_school"):
            school = frappe.db.get_value(
                "User", frappe.session.user, "custom_school"
            )
        if not school:
            frappe.throw(
                _(
                    "No school is linked to your account. Please contact the administrator."
                )
            )
        return school

    frappe.throw(_("You don't have permission to access this data"))


def _apply_school_filter(filters, school):
    if school:
        filters["school"] = school
    return filters


def _resolve_school(school, admin_school):
    """
    Resolve the school to query, enforcing the School Admin's scope.
    School Admins can never see data outside their own school.
    """
    if school and admin_school and school != admin_school:
        frappe.throw(
            _("You don't have permission to view this school's data")
        )
    return school or admin_school


@frappe.whitelist()
def get_admin_dashboard(school=None):
    """
    Get overview data for the admin's school (or all schools for System Manager).
    Returns school info, teachers, students and classes counts.
    """
    admin_school = _get_admin_school()
    school = _resolve_school(school, admin_school)

    filters = _apply_school_filter({}, school)

    teachers = frappe.get_all(
        "Instructor",
        filters=filters,
        fields=["name", "instructor_name", "instructor_email"],
        order_by="instructor_name asc",
        ignore_permissions=True,
    )
    students = frappe.get_all(
        "Student",
        filters=filters,
        fields=["name", "student_name", "student_email_id"],
        order_by="student_name asc",
        ignore_permissions=True,
    )
    classes = frappe.get_all(
        "Student Group",
        filters=filters,
        fields=["name", "student_group_name", "program", "program_name"],
        order_by="student_group_name asc",
        ignore_permissions=True,
    )

    school_info = None
    if school:
        school_doc = frappe.get_all(
            "School",
            filters={"name": school},
            fields=["name", "school_name", "city", "state", "country"],
            limit=1,
            ignore_permissions=True,
        )
        if school_doc:
            school_info = school_doc[0]
        else:
            school_info = {"name": school, "school_name": school}

    return {
        "school": school_info,
        "teachers": teachers,
        "students": students,
        "classes": classes,
    }


@frappe.whitelist()
def get_admin_teachers(school=None):
    """
    Get teachers of a school with their assigned classes (Course Schedules).
    """
    admin_school = _get_admin_school()
    school = _resolve_school(school, admin_school)

    filters = _apply_school_filter({}, school)

    teacher_fields = ["name", "instructor_name", "instructor_email", "school"]
    if frappe.db.has_column("Instructor", "custom_subjects"):
        teacher_fields.append("custom_subjects")

    teachers = frappe.get_all(
        "Instructor",
        filters=filters,
        fields=teacher_fields,
        order_by="instructor_name asc",
        ignore_permissions=True,
    )

    for t in teachers:
        raw = t.get("custom_subjects") or ""
        t["subjects"] = [s.strip() for s in raw.split(",") if s.strip()]
        t.pop("custom_subjects", None)

    teacher_ids = [t.name for t in teachers]
    schedules = []
    if teacher_ids:
        schedules = frappe.get_all(
            "Course Schedule",
            filters={"instructor": ["in", teacher_ids]},
            fields=[
                "instructor",
                "course",
                "course_name",
                "student_group",
                "student_group_name",
                "schedule_date",
                "from_time",
                "to_time",
                "room",
            ],
            order_by="course_name asc",
            ignore_permissions=True,
        )

    schedules_by_instructor = {}
    for s in schedules:
        schedules_by_instructor.setdefault(s.instructor, []).append(s)

    for t in teachers:
        t["classes"] = schedules_by_instructor.get(t.name, [])

    return teachers


@frappe.whitelist()
def get_admin_classes(school=None):
    """
    Get classes (Student Groups) of a school.
    Each class includes its enrolled students with roll numbers.
    """
    admin_school = _get_admin_school()
    school = _resolve_school(school, admin_school)

    filters = _apply_school_filter({}, school)

    classes = frappe.get_all(
        "Student Group",
        filters=filters,
        fields=[
            "name",
            "student_group_name",
            "program",
            "program_name",
            "school",
            "school_name",
        ],
        order_by="student_group_name asc",
        ignore_permissions=True,
    )

    for cls in classes:
        enrollments = frappe.get_all(
            "Student Group Student",
            filters={"parent": cls.name, "active": 1},
            fields=["student", "student_name", "group_roll_number"],
            order_by="group_roll_number asc",
            ignore_permissions=True,
        )

        student_ids = [e.student for e in enrollments]
        student_details = {}
        if student_ids:
            student_records = frappe.get_all(
                "Student",
                filters={"name": ["in", student_ids]},
                fields=["name", "student_name", "student_email_id", "gender"],
                ignore_permissions=True,
            )
            student_details = {s.name: s for s in student_records}

        students = []
        for e in enrollments:
            details = student_details.get(e.student, {})
            students.append(
                {
                    "name": e.student,
                    "student": e.student,
                    "student_name": e.student_name or details.get("student_name", ""),
                    "student_email_id": details.get("student_email_id", ""),
                    "gender": details.get("gender", ""),
                    "roll_number": e.group_roll_number or "",
                }
            )

        cls["students"] = students
        cls["student_count"] = len(students)

    return classes


@frappe.whitelist()
def get_admin_students(school=None):
    """
    Get students of a school with their class and roll number.
    """
    admin_school = _get_admin_school()
    school = _resolve_school(school, admin_school)

    filters = _apply_school_filter({}, school)

    students = frappe.get_all(
        "Student",
        filters=filters,
        fields=[
            "name",
            "student_name",
            "student_email_id",
            "gender",
            "school",
            "school_name",
        ],
        order_by="student_name asc",
        ignore_permissions=True,
    )

    student_ids = [s.name for s in students]
    enrollments = []
    if student_ids:
        enrollments = frappe.get_all(
            "Student Group Student",
            filters={"student": ["in", student_ids], "active": 1},
            fields=["student", "parent", "group_roll_number"],
            ignore_permissions=True,
        )

    group_ids = {e.parent for e in enrollments}
    groups = {}
    if group_ids:
        group_records = frappe.get_all(
            "Student Group",
            filters={"name": ["in", list(group_ids)]},
            fields=["name", "student_group_name"],
            ignore_permissions=True,
        )
        groups = {g.name: g for g in group_records}

    group_map = {}
    roll_map = {}
    for e in enrollments:
        group = groups.get(e.parent)
        group_map.setdefault(e.student, group.student_group_name if group else e.parent)
        if e.group_roll_number:
            roll_map[e.student] = e.group_roll_number

    for s in students:
        s["student_group"] = group_map.get(s.name, "")
        s["student_group_name"] = group_map.get(s.name, "")
        s["roll_number"] = roll_map.get(s.name, "")

    return students


def _instructor_subjects(instructor):
    """Comma-separated subjects list from the Instructor custom field (if any)."""
    if not frappe.db.has_column("Instructor", "custom_subjects"):
        return []
    raw = frappe.db.get_value("Instructor", instructor, "custom_subjects") or ""
    return [s.strip() for s in raw.split(",") if s.strip()]


@frappe.whitelist()
def get_timetable(school=None, **kwargs):
    """
    Get the weekly timetable for a school, or for a single class when
    `class` is passed (Student Group name).

    Returns {"periods": [...], "entries": [...]} — the school's configured
    periods plus entries with class/teacher names resolved and subjects pinned
    per slot. System Manager / Administrator can view any school; School
    Admins are locked to their own school.
    """
    admin_school = _get_admin_school()
    school = _resolve_school(school, admin_school)
    class_id = kwargs.get("class") or kwargs.get("class_id")

    filters = _apply_school_filter({}, school)
    if class_id:
        filters["student_group"] = class_id

    rows = frappe.get_all(
        "School Timetable Entry",
        filters=filters,
        fields=["name", "school", "student_group", "instructor", "day", "period", "subject"],
        ignore_permissions=True,
    )

    group_ids = {r.student_group for r in rows}
    class_names = {}
    if group_ids:
        groups = frappe.get_all(
            "Student Group",
            filters={"name": ["in", list(group_ids)]},
            fields=["name", "student_group_name"],
            ignore_permissions=True,
        )
        class_names = {g.name: g.student_group_name for g in groups}

    instructor_ids = {r.instructor for r in rows}
    teacher_names = {}
    if instructor_ids:
        instructors = frappe.get_all(
            "Instructor",
            filters={"name": ["in", list(instructor_ids)]},
            fields=["name", "instructor_name"],
            ignore_permissions=True,
        )
        teacher_names = {i.name: i.instructor_name for i in instructors}

    day_order = {d: i for i, d in enumerate(TIMETABLE_DAYS)}
    data = []
    for r in rows:
        data.append(
            {
                "id": r.name,
                "school_id": r.school,
                "class_id": r.student_group,
                "class_name": class_names.get(r.student_group),
                "day": r.day,
                "period": r.period,
                "teacher_id": r.instructor,
                "teacher_name": teacher_names.get(r.instructor, "Unknown teacher"),
                "subject": r.subject,
                "teacher_status": "Active",
            }
        )
    data.sort(key=lambda e: (day_order.get(e["day"], 99), e["period"]))
    return {"periods": get_school_periods(school), "entries": data}


@frappe.whitelist()
def set_timetable_entry(class_id=None, day=None, period=None, teacher_id=None, subject=None, **kwargs):
    """
    Create or update one weekly slot for a class (Student Group).

    Schedule invariants (one slot per class + day + period, no instructor
    double-booking, valid day and period) are enforced by the School Timetable
    Entry controller's validate and backed by unique indexes, so this endpoint
    only handles permissions, school membership, and the subject check. The
    "save over existing slot" semantics stay here: an existing entry for the
    same class + day + period is updated, not duplicated.
    """
    admin_school = _get_admin_school()

    if not class_id:
        frappe.throw(_("Class is required"))
    cls = frappe.db.get_value(
        "Student Group", class_id, ["school", "student_group_name"], as_dict=True
    )
    if not cls:
        frappe.throw(_("Class not found"))
    if admin_school and cls.school != admin_school:
        frappe.throw(_("You don't have permission to modify this class's timetable"))

    instructor = frappe.db.get_value(
        "Instructor", teacher_id, ["instructor_name", "school"], as_dict=True
    )
    if not instructor:
        frappe.throw(_("Instructor not found"))
    if admin_school and instructor.school != admin_school:
        frappe.throw(_("This instructor doesn't belong to the class's school"))

    subject = (subject or "").strip()
    if not subject:
        frappe.throw(_("A subject is required for this period"))
    teacher_subjects = _instructor_subjects(teacher_id)
    if teacher_subjects and subject not in teacher_subjects:
        frappe.throw(
            _("{0} doesn't teach {1}").format(instructor.instructor_name, subject)
        )

    period = frappe.utils.cint(period)

    # one slot per class + day + period — saving replaces the existing slot
    existing = frappe.db.get_value(
        "School Timetable Entry",
        {"student_group": class_id, "day": day, "period": period},
        "name",
    )
    try:
        if existing:
            doc = frappe.get_doc("School Timetable Entry", existing)
            doc.instructor = teacher_id
            doc.subject = subject
            doc.save(ignore_permissions=True)
        else:
            frappe.get_doc(
                {
                    "doctype": "School Timetable Entry",
                    "school": cls.school,
                    "student_group": class_id,
                    "instructor": teacher_id,
                    "day": day,
                    "period": period,
                    "subject": subject,
                }
            ).insert(ignore_permissions=True)
        frappe.db.commit()
    except frappe.IntegrityError:
        # Lost a race against a concurrent save — the unique indexes reject the
        # duplicate slot or double-booking at the database level.
        frappe.db.rollback()
        frappe.throw(
            _("This slot was just scheduled by someone else — refresh and try again")
        )
    return {"message": "Timetable updated"}


@frappe.whitelist()
def update_timetable_periods(school=None, periods=None, **kwargs):
    """
    Set a school's weekly periods: a list of {"n": int, "time": str}.

    Period times are per-school data (stored on the School doctype), so each
    school can run its own schedule. Changing the count does not delete
    timetable entries in removed periods — they stay in the database but are
    hidden from the grid.
    """
    admin_school = _get_admin_school()
    school = _resolve_school(school, admin_school)
    if not school:
        frappe.throw(_("A school is required"))

    if not isinstance(periods, list):
        frappe.throw(_("Periods must be a list"))
    cleaned = normalize_periods(periods)
    if not cleaned:
        frappe.throw(_("At least one period with a valid time is required"))

    if not frappe.db.has_column("School", "custom_timetable_periods"):
        frappe.throw(
            _("Timetable periods aren't set up yet — run `bench migrate` to add the field")
        )

    school_doc = frappe.get_doc("School", school)
    school_doc.custom_timetable_periods = frappe.as_json(cleaned)
    school_doc.save(ignore_permissions=True)
    frappe.db.commit()
    return {"message": "Periods updated", "periods": cleaned}


@frappe.whitelist()
def remove_timetable_entry(id=None, **kwargs):
    """Remove one weekly slot by entry name."""
    admin_school = _get_admin_school()
    if not id:
        frappe.throw(_("Entry id is required"))

    doc = frappe.get_doc("School Timetable Entry", id)
    if admin_school and doc.school != admin_school:
        frappe.throw(_("You don't have permission to remove this entry"))
    doc.delete(ignore_permissions=True)
    frappe.db.commit()
    return {"message": "Timetable entry removed"}


# ---------------------------------------------------------------------------
# CRUD — teachers, classes, students
#
# The web consoles call these exact names in live mode (school_connect.api.*),
# and the response shapes mirror what the consoles render: every payload has
# an `id`/`name`/`email` trio plus the fields the UI shows. Mutations follow
# the app's existing conventions: school scope is enforced via
# _get_admin_school/_resolve_school, writes run with ignore_permissions=True
# and end with frappe.db.commit().
# ---------------------------------------------------------------------------


def _teacher_subjects(instructor):
    """List of subjects from the Instructor's comma-separated custom field."""
    if not frappe.db.has_column("Instructor", "custom_subjects"):
        return []
    raw = frappe.db.get_value("Instructor", instructor, "custom_subjects") or ""
    return [s.strip() for s in raw.split(",") if s.strip()]


def _teacher_status(instructor_email):
    """Active/Inactive derived from the linked User account (if any)."""
    if not instructor_email or not frappe.db.exists("User", instructor_email):
        return "Active"
    return "Active" if frappe.db.get_value("User", instructor_email, "enabled") else "Inactive"


def _teacher_payload(instructor_name):
    """Console-shaped teacher payload (id/name/email/subjects/classes/status)."""
    inst = frappe.db.get_value(
        "Instructor", instructor_name,
        ["instructor_name", "instructor_email", "school"], as_dict=True,
    )
    if not inst:
        return None
    subjects = _teacher_subjects(instructor_name) or ["General"]
    schedules = frappe.get_all(
        "Course Schedule",
        filters={"instructor": instructor_name},
        fields=["student_group", "student_group_name"],
        ignore_permissions=True,
    )
    school_name = frappe.db.get_value("School", inst.school, "school_name") if inst.school else None
    return {
        "id": instructor_name,
        "name": inst.instructor_name,
        "email": inst.instructor_email,
        "subjects": subjects,
        "subject": subjects[0],
        "school_id": inst.school,
        "school_name": school_name,
        "classes": [s.student_group_name for s in schedules if s.student_group_name],
        "class_ids": [s.student_group for s in schedules if s.student_group],
        "status": _teacher_status(inst.instructor_email),
    }


def _student_payload(student_name):
    """Console-shaped student payload (id/name/email/roll/class/status)."""
    st = frappe.db.get_value(
        "Student", student_name,
        ["student_name", "student_email_id", "school", "school_name"], as_dict=True,
    )
    if not st:
        return None
    enrollment = frappe.db.get_value(
        "Student Group Student",
        {"student": student_name, "active": 1},
        ["parent", "group_roll_number"], as_dict=True,
    )
    class_id = enrollment.parent if enrollment else None
    class_name = frappe.db.get_value("Student Group", class_id, "student_group_name") if class_id else None
    enabled = frappe.db.get_value("Student", student_name, "enabled")
    return {
        "id": student_name,
        "name": st.student_name,
        "email": st.student_email_id,
        "roll_number": enrollment.group_roll_number if enrollment and enrollment.group_roll_number else "",
        "class_id": class_id,
        "class_name": class_name,
        "school_id": st.school,
        "school_name": st.school_name or (frappe.db.get_value("School", st.school, "school_name") if st.school else None),
        "status": "Active" if enabled else "Inactive",
        # attendance is derived from Student Attendance records; the console
        # falls back to 0 when a student has no records yet
        "attendance_pct": 0,
    }


def _class_teacher_names(student_group):
    """Instructor names for a class, from its Course Schedules."""
    instructors = frappe.get_all(
        "Course Schedule",
        filters={"student_group": student_group},
        fields=["instructor"],
        ignore_permissions=True,
    )
    names = []
    for row in instructors:
        name = frappe.db.get_value("Instructor", row.instructor, "instructor_name")
        if name and name not in names:
            names.append(name)
    return names


def _class_payload(sg_name):
    """Console-shaped class payload (id/name/program/room/counts/teachers)."""
    sg = frappe.db.get_value(
        "Student Group", sg_name,
        ["student_group_name", "program", "program_name", "school", "school_name"], as_dict=True,
    )
    if not sg:
        return None
    student_count = frappe.db.count(
        "Student Group Student", filters={"parent": sg_name, "active": 1}
    )
    return {
        "id": sg_name,
        "name": sg.student_group_name,
        "program": sg.program_name or sg.program or "",
        "room": "",  # room lives on timetable (Course Schedule) entries, not the group
        "school_id": sg.school,
        "school_name": sg.school_name,
        "student_count": student_count,
        "teachers": _class_teacher_names(sg_name),
    }


def _class_detail(sg_name):
    """Console-shaped class detail (adds the enrolled students roster)."""
    payload = _class_payload(sg_name)
    if payload is None:
        return None
    enrollments = frappe.get_all(
        "Student Group Student",
        filters={"parent": sg_name, "active": 1},
        fields=["student", "student_name", "group_roll_number"],
        order_by="group_roll_number asc",
        ignore_permissions=True,
    )
    students = []
    for e in enrollments:
        student = _student_payload(e.student)
        if student:
            student["roll_number"] = e.group_roll_number or student.get("roll_number", "")
            students.append(student)
    payload["students"] = students
    return payload


def _resolve_class_school(sg_name):
    """School a Student Group belongs to (None if it doesn't exist)."""
    return frappe.db.get_value("Student Group", sg_name, "school")


def _require_school(school, admin_school):
    """Resolve + validate a school id for a mutation, enforcing admin scope."""
    resolved = _resolve_school(school, admin_school)
    if not resolved:
        frappe.throw(_("A school is required"))
    return resolved


@frappe.whitelist()
def create_teacher(name=None, email=None, password=None, school=None, class_ids=None, subjects=None, subject=None):
    """
    Create a teacher: a User with the Instructor role plus an Instructor record.
    Accepts class_ids (Student Group names) for parity with the console form, but
    teacher-to-class assignment in the real model flows through the timetable
    (Course Schedule), so only the subjects are persisted here.
    """
    admin_school = _get_admin_school()
    school = _require_school(school, admin_school)

    name = (name or "").strip()
    email = (email or "").strip().lower()
    if not name:
        frappe.throw(_("Name is required"))
    if not email:
        frappe.throw(_("Email is required"))
    if not password:
        frappe.throw(_("Password is required"))
    if frappe.db.exists("User", email):
        frappe.throw(_("An account with this email already exists"))

    subject_list = [s.strip() for s in (subjects or [subject or "General"]) if s.strip()]
    subject_list = subject_list or ["General"]

    # User with Instructor role (pattern mirrors auth.signup_student)
    user = frappe.get_doc({
        "doctype": "User",
        "email": email,
        "first_name": name.split()[0],
        "last_name": " ".join(name.split()[1:]),
        "full_name": name,
        "send_welcome_email": 0,
        "user_type": "System User",
    })
    user.insert(ignore_permissions=True)
    user.new_password = password
    user.append("roles", {"role": "Instructor"})
    user.save(ignore_permissions=True)

    instructor = frappe.get_doc({
        "doctype": "Instructor",
        "instructor_name": name,
        "instructor_email": email,
        "school": school,
    })
    if frappe.db.has_column("Instructor", "custom_subjects"):
        instructor.custom_subjects = ", ".join(subject_list)
    instructor.insert(ignore_permissions=True)
    frappe.db.commit()
    return _teacher_payload(instructor.name)


@frappe.whitelist()
def update_teacher(id=None, name=None, email=None, password=None, class_ids=None, subjects=None, subject=None):
    """Update a teacher's name, email, password and subjects."""
    admin_school = _get_admin_school()
    if not id or not frappe.db.exists("Instructor", id):
        frappe.throw(_("Teacher not found"))
    school = frappe.db.get_value("Instructor", id, "school")
    _resolve_school(school, admin_school)  # throws when scoped to another school

    name = (name or "").strip()
    email = (email or "").strip().lower()
    if not name:
        frappe.throw(_("Name is required"))
    if not email:
        frappe.throw(_("Email is required"))

    instructor = frappe.get_doc("Instructor", id)
    old_email = instructor.instructor_email
    instructor.instructor_name = name
    instructor.instructor_email = email
    if frappe.db.has_column("Instructor", "custom_subjects"):
        subject_list = [s.strip() for s in (subjects or [subject or "General"]) if s.strip()]
        instructor.custom_subjects = ", ".join(subject_list or ["General"])
    instructor.save(ignore_permissions=True)

    # keep the linked User account in sync (password + name + email when changed)
    if old_email and frappe.db.exists("User", old_email):
        if email != old_email and frappe.db.exists("User", email):
            frappe.throw(_("An account with this email already exists"))
        user = frappe.get_doc("User", old_email)
        user.first_name = name.split()[0]
        user.last_name = " ".join(name.split()[1:])
        user.full_name = name
        if email != old_email:
            user.email = email
        if password:
            user.new_password = password
        user.save(ignore_permissions=True)
        if email != old_email:
            frappe.rename_doc("User", old_email, email, force=True)
    elif password:
        frappe.throw(_("Password cannot be set: no User account exists for this teacher"))
    frappe.db.commit()
    return _teacher_payload(id)


@frappe.whitelist()
def set_teacher_status(id=None, status=None):
    """Enable/disable a teacher's account (maps to the linked User's `enabled`)."""
    admin_school = _get_admin_school()
    if not id or not frappe.db.exists("Instructor", id):
        frappe.throw(_("Teacher not found"))
    school = frappe.db.get_value("Instructor", id, "school")
    _resolve_school(school, admin_school)

    enabled = 0 if status == "Inactive" else 1
    email = frappe.db.get_value("Instructor", id, "instructor_email")
    if email and frappe.db.exists("User", email):
        frappe.db.set_value("User", email, "enabled", enabled)
        frappe.db.commit()
    return _teacher_payload(id)


@frappe.whitelist()
def delete_teacher(id=None):
    """Delete an Instructor and its linked User account."""
    admin_school = _get_admin_school()
    if not id or not frappe.db.exists("Instructor", id):
        frappe.throw(_("Teacher not found"))
    school = frappe.db.get_value("Instructor", id, "school")
    _resolve_school(school, admin_school)

    email = frappe.db.get_value("Instructor", id, "instructor_email")
    frappe.delete_doc("Instructor", id, force=1)
    if email and frappe.db.exists("User", email):
        frappe.delete_doc("User", email, force=1)
    frappe.db.commit()
    return {"message": "Teacher deleted", "id": id}


@frappe.whitelist()
def get_admin_class(id=None):
    """Single class with its student roster (console class detail page)."""
    admin_school = _get_admin_school()
    if not id or not frappe.db.exists("Student Group", id):
        frappe.throw(_("Class not found"))
    _resolve_school(_resolve_class_school(id), admin_school)
    return _class_detail(id)


@frappe.whitelist()
def create_class(name=None, program=None, room=None, school=None, teacher_ids=None):
    """
    Create a class (Student Group).
    room and teacher_ids are accepted for parity with the console form; the real
    model stores them on timetable (Course Schedule) entries, so only the group
    name/program/school are persisted here.
    """
    admin_school = _get_admin_school()
    school = _require_school(school, admin_school)

    name = (name or "").strip()
    if not name:
        frappe.throw(_("Class name is required"))
    if frappe.db.exists("Student Group", {"student_group_name": name, "school": school}):
        frappe.throw(_("A class with this name already exists in this school"))

    group = frappe.get_doc({
        "doctype": "Student Group",
        "student_group_name": name,
        "school": school,
    })
    if program and frappe.db.exists("Program", program):
        group.program = program
    group.insert(ignore_permissions=True)
    frappe.db.commit()
    return _class_payload(group.name)


@frappe.whitelist()
def update_class(id=None, name=None, program=None, room=None, teacher_ids=None):
    """Rename a class and/or change its program."""
    admin_school = _get_admin_school()
    if not id or not frappe.db.exists("Student Group", id):
        frappe.throw(_("Class not found"))
    _resolve_school(_resolve_class_school(id), admin_school)

    name = (name or "").strip()
    if not name:
        frappe.throw(_("Class name is required"))

    group = frappe.get_doc("Student Group", id)
    group.student_group_name = name
    if program and frappe.db.exists("Program", program):
        group.program = program
    group.save(ignore_permissions=True)
    frappe.db.commit()
    return _class_payload(id)


@frappe.whitelist()
def delete_class(id=None):
    """Delete a class (Student Group) and its enrollments + timetable rows."""
    admin_school = _get_admin_school()
    if not id or not frappe.db.exists("Student Group", id):
        frappe.throw(_("Class not found"))
    _resolve_school(_resolve_class_school(id), admin_school)

    for entry in frappe.get_all(
        "School Timetable Entry", filters={"student_group": id}, pluck="name"
    ):
        frappe.delete_doc("School Timetable Entry", entry, force=1)
    for schedule in frappe.get_all(
        "Course Schedule", filters={"student_group": id}, pluck="name"
    ):
        frappe.delete_doc("Course Schedule", schedule, force=1)
    frappe.delete_doc("Student Group", id, force=1)
    frappe.db.commit()
    return {"message": "Class deleted", "id": id}


@frappe.whitelist()
def get_admin_student(id=None):
    """Single student with class + teachers (console student detail page)."""
    admin_school = _get_admin_school()
    if not id or not frappe.db.exists("Student", id):
        frappe.throw(_("Student not found"))
    st = frappe.db.get_value("Student", id, "school", as_dict=True)
    _resolve_school(st.school, admin_school)

    payload = _student_payload(id)
    if payload and payload.get("class_id"):
        payload["teachers"] = _class_teacher_names(payload["class_id"])
    else:
        payload["teachers"] = []
    return payload


@frappe.whitelist()
def create_student(name=None, email=None, class_id=None, roll_number=None, school=None, gender=None, status=None):
    """
    Create a student (Student doc) and enroll them in a class with a roll number.
    No User account is created here — student login flows through signup_student.
    """
    admin_school = _get_admin_school()
    school = _require_school(school, admin_school)

    name = (name or "").strip()
    email = (email or "").strip().lower()
    if not name:
        frappe.throw(_("Student name is required"))
    if not email:
        frappe.throw(_("Email is required"))
    if not class_id or not frappe.db.exists("Student Group", class_id):
        frappe.throw(_("Unknown class"))
    _resolve_school(_resolve_class_school(class_id), admin_school)
    if frappe.db.exists("Student", {"student_email_id": email}):
        frappe.throw(_("A student with this email already exists"))

    student = frappe.get_doc({
        "doctype": "Student",
        "student_name": name,
        "student_email_id": email,
        "school": school,
    })
    if gender:
        student.gender = gender
    student.insert(ignore_permissions=True)

    # roll number: explicit value or next free number in the class
    roll = None
    if roll_number:
        roll = frappe.utils.cint(roll_number)
        clash = frappe.db.exists(
            "Student Group Student",
            {"parent": class_id, "group_roll_number": roll, "active": 1},
        )
        if clash:
            frappe.db.rollback()
            frappe.throw(_("Roll number {0} is already taken in this class").format(roll))
    else:
        last = frappe.db.get_all(
            "Student Group Student",
            filters={"parent": class_id, "active": 1},
            fields=["group_roll_number"],
            order_by="group_roll_number desc",
            limit=1,
        )
        roll = (last[0].group_roll_number or 0) + 1 if last else 1

    group = frappe.get_doc("Student Group", class_id)
    group.append("students", {
        "student": student.name,
        "student_name": name,
        "group_roll_number": roll,
    })
    group.save(ignore_permissions=True)
    frappe.db.commit()
    return _student_payload(student.name)


@frappe.whitelist()
def update_student(id=None, name=None, email=None, class_id=None, roll_number=None, status=None):
    """Update a student's profile and move their enrollment when the class changes."""
    admin_school = _get_admin_school()
    if not id or not frappe.db.exists("Student", id):
        frappe.throw(_("Student not found"))
    st = frappe.db.get_value("Student", id, "school", as_dict=True)
    _resolve_school(st.school, admin_school)

    name = (name or "").strip()
    email = (email or "").strip().lower()
    if not name:
        frappe.throw(_("Student name is required"))
    if not email:
        frappe.throw(_("Email is required"))

    student = frappe.get_doc("Student", id)
    student.student_name = name
    student.student_email_id = email
    student.save(ignore_permissions=True)

    # move enrollment when the class changes
    current = frappe.db.get_value(
        "Student Group Student",
        {"student": id, "active": 1},
        ["name", "parent", "group_roll_number"], as_dict=True,
    )
    new_class = class_id or (current.parent if current else None)
    if new_class and new_class != (current.parent if current else None):
        if not frappe.db.exists("Student Group", new_class):
            frappe.throw(_("Unknown class"))
        _resolve_school(_resolve_class_school(new_class), admin_school)
        if current:
            frappe.db.set_value("Student Group Student", current.name, "active", 0)
        roll = frappe.utils.cint(roll_number) if roll_number else None
        if not roll:
            last = frappe.db.get_all(
                "Student Group Student",
                filters={"parent": new_class, "active": 1},
                fields=["group_roll_number"],
                order_by="group_roll_number desc",
                limit=1,
            )
            roll = (last[0].group_roll_number or 0) + 1 if last else 1
        group = frappe.get_doc("Student Group", new_class)
        group.append("students", {
            "student": id,
            "student_name": name,
            "group_roll_number": roll,
        })
        group.save(ignore_permissions=True)
    elif current and roll_number:
        frappe.db.set_value(
            "Student Group Student", current.name, "group_roll_number", frappe.utils.cint(roll_number)
        )
    frappe.db.commit()
    return _student_payload(id)


@frappe.whitelist()
def delete_student(id=None):
    """Delete a student and their enrollments in all classes."""
    admin_school = _get_admin_school()
    if not id or not frappe.db.exists("Student", id):
        frappe.throw(_("Student not found"))
    st = frappe.db.get_value("Student", id, "school", as_dict=True)
    _resolve_school(st.school, admin_school)

    for enrollment in frappe.get_all(
        "Student Group Student", filters={"student": id}, pluck="name"
    ):
        frappe.delete_doc("Student Group Student", enrollment, force=1)
    frappe.delete_doc("Student", id, force=1)
    frappe.db.commit()
    return {"message": "Student deleted", "id": id}


@frappe.whitelist()
def set_student_status(id=None, status=None):
    """Enable/disable a student (maps to the Student doctype's `enabled`)."""
    admin_school = _get_admin_school()
    if not id or not frappe.db.exists("Student", id):
        frappe.throw(_("Student not found"))
    st = frappe.db.get_value("Student", id, "school", as_dict=True)
    _resolve_school(st.school, admin_school)

    frappe.db.set_value("Student", id, "enabled", 0 if status == "Inactive" else 1)
    frappe.db.commit()
    return _student_payload(id)
