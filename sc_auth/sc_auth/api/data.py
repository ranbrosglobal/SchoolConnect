"""App-shaped data endpoints for the School Connect Flutter app.

These whitelisted methods shape the stock education doctypes (Student,
Student Group, Course Schedule, Assessment Plan) plus our own
`Student Submission` doctype into the JSON the Flutter models expect:

  my_classes()                    → teacher's course schedules (+ names)
  class_students(course_schedule) → roster for a schedule's group
  my_attendance_summary()         → student attendance percentages
  my_attendance(course=None)      → student attendance rows
  my_assignments()                → student assignment list (+ submission)
  teacher_assignments()           → teacher assignment list (+ stats)
  create/update/delete_assignment → assignment lifecycle (Assessment Plan)
  assignment_submissions(plan)    → submissions for a plan
  submit/unsubmit/delete_submission
  grade_submission(submission, score, feedback=None)
  admin_dashboard()               → school/teachers/students/classes counts
  student_groups()                → signup: groups (+ program) — guest
  programs()                      → signup: programs — guest
  school_profile()                → school name/logo/contact info — guest
  update_school_profile()         → admin: edit school name/contact info
  upload_school_logo()            → admin: multipart logo upload
  my_timetable(week_start)        → student: weekly grid + teachers + subjects

All endpoints are session-authenticated (guest only for the signup pickers)
and enforce the caller's role.
"""

import datetime
from contextlib import contextmanager

import frappe
from frappe import _
from frappe.utils import flt

from .auth import _resolve_role, _current_academic_year

ASSESSMENT_GROUP_ROOT = "All Assessment Groups"
GRADING_SCALE = "Percentage"
CRITERION = "Total Marks"
EVENING_START = "18:00:00"
EVENING_END = "19:00:00"


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def _require_role(*roles):
    role = _resolve_role(frappe.session.user)
    if role not in roles:
        frappe.throw(
            _("You do not have permission to access this resource."),
            frappe.PermissionError,
        )
    return role


@contextmanager
def _elevated():
    """Temporarily run as Administrator for permission-free reads/writes inside
    role-gated endpoints. The `_require_role` check that ran first IS the
    authorization — this only widens the *document* permission checks (the
    School Admin role, for example, has no per-doctype grants on the stock
    education doctypes)."""
    original = frappe.session.user
    frappe.set_user("Administrator")
    try:
        yield
    finally:
        frappe.set_user(original)


def _current_student():
    student = frappe.db.get_value("Student", {"user": frappe.session.user}, "name")
    if not student:
        frappe.throw(_("No Student record linked to your account."), frappe.PermissionError)
    return student


def _current_instructor():
    user = frappe.get_doc("User", frappe.session.user)
    instr = frappe.db.get_value(
        "Instructor", {"instructor_name": user.full_name}, "name"
    )
    if not instr:
        frappe.throw(_("No Instructor record linked to your account."), frappe.PermissionError)
    return instr


def _course_name(course):
    return frappe.db.get_value("Course", course, "course_name") if course else None


def _group_name(student_group):
    if not student_group:
        return None
    return frappe.db.get_value("Student Group", student_group, "student_group_name")


def _group_program(student_group):
    return frappe.db.get_value("Student Group", student_group, "program") if student_group else None


def _student_email(student):
    return frappe.db.get_value("Student", student, "student_email_id") if student else None


def _group_students(student_group):
    """[(student, student_name, roll_number)] for a group, active first."""
    rows = frappe.db.get_all(
        "Student Group Student",
        filters={"parent": student_group},
        fields=["student", "student_name", "group_roll_number", "active"],
        order_by="group_roll_number",
    )
    return [
        {"student": r.student, "student_name": r.student_name, "roll_number": r.group_roll_number}
        for r in rows
        if r.active
    ]


def _group_size(student_group):
    return len(_group_students(student_group))


def _submissions_for_plan(plan):
    return frappe.db.get_all(
        "Student Submission",
        filters={"assessment_plan": plan},
        fields=["name", "assessment_plan", "student", "student_name", "status", "score",
                "feedback", "submission_file", "submitted_at", "graded_at", "graded_by"],
        order_by="submitted_at desc",
    )


def _shape_submission(s):
    return {
        "name": s["name"],
        "assignment": s.get("assessment_plan"),
        "student": s["student"],
        "student_name": s["student_name"],
        "student_email_id": _student_email(s["student"]),
        "file": s.get("submission_file"),
        "file_name": s.get("submission_file"),
        "file_url": s.get("file_url"),
        "submitted_at": s.get("submitted_at"),
        "grade": flt(s.get("score") or 0) if s.get("status") == "Graded" else None,
        "feedback": s.get("feedback"),
        "status": s.get("status"),
    }


def _shape_plan(plan, student=None):
    """Shape an Assessment Plan for the app's AssignmentModel."""
    sub = None
    if student:
        rows = frappe.db.get_all(
            "Student Submission",
            filters={"assessment_plan": plan.name, "student": student},
            fields=["name", "status", "score", "feedback", "submission_file", "submitted_at"],
        )
        if rows:
            r = rows[0]
            sub = {
                "status": r.status,
                "grade": flt(r.score or 0) if r.status == "Graded" else None,
                "feedback": r.feedback,
                "file": r.submission_file,
                "file_name": r.submission_file,
                "submitted_at": str(r.submitted_at) if r.submitted_at else None,
            }
    submissions = _submissions_for_plan(plan.name)
    graded = [s for s in submissions if s["status"] == "Graded"]
    return {
        "name": plan.name,
        "title": plan.assessment_name,
        "description": None,
        "course": plan.course,
        "course_name": _course_name(plan.course),
        "student_group": plan.student_group,
        "student_group_name": _group_name(plan.student_group),
        "instructor": plan.examiner,
        "instructor_name": plan.examiner_name or (
            frappe.db.get_value("Instructor", plan.examiner, "instructor_name")
            if plan.examiner else None
        ),
        "due_date": str(plan.schedule_date) if plan.schedule_date else None,
        "from_time": str(plan.from_time) if plan.from_time else None,
        "to_time": str(plan.to_time) if plan.to_time else None,
        "creation": str(plan.creation) if plan.creation else None,
        "attachment": None,
        "attachment_name": None,
        "total_students": _group_size(plan.student_group),
        "submitted_count": len(submissions),
        "graded_count": len(graded),
        "submission": sub,
    }


# --------------------------------------------------------------------------
# teacher
# --------------------------------------------------------------------------
@frappe.whitelist()
def my_classes():
    _require_role("Instructor", "System Manager")
    instructor = _current_instructor()
    # Upcoming classes only — past weeks are attendance history, not classes
    # the teacher still has to mark.
    schedules = frappe.db.get_all(
        "Course Schedule",
        filters={"instructor": instructor, "schedule_date": (">=", frappe.utils.today())},
        fields=["name", "course", "student_group", "instructor", "instructor_name",
                "program", "schedule_date", "from_time", "to_time", "room"],
        order_by="schedule_date asc",
    )
    out = []
    for s in schedules:
        out.append({
            "name": s.name,
            "course": s.course,
            "course_name": _course_name(s.course),
            "student_group": s.student_group,
            "student_group_name": _group_name(s.student_group),
            "instructor": s.instructor,
            "instructor_name": s.instructor_name,
            "program": s.program,
            "school": None,
            "schedule_date": str(s.schedule_date) if s.schedule_date else None,
            "from_time": str(s.from_time) if s.from_time else None,
            "to_time": str(s.to_time) if s.to_time else None,
            "room": s.room,
            "is_completed": None,
        })
    return out


@frappe.whitelist()
def class_students(course_schedule):
    _require_role("Instructor", "System Manager")
    schedule = frappe.get_doc("Course Schedule", course_schedule)
    group = schedule.student_group
    students = []
    for row in _group_students(group):
        info = frappe.db.get_value(
            "Student", row["student"],
            ["student_email_id", "gender", "date_of_birth", "city", "state", "country"],
            as_dict=True,
        ) or {}
        students.append({
            "name": row["student"],
            "student_name": row["student_name"],
            "student_email_id": info.get("student_email_id"),
            "gender": info.get("gender"),
            "date_of_birth": str(info.get("date_of_birth")) if info.get("date_of_birth") else None,
            "student_group": group,
            "student_group_name": _group_name(group),
            "program": _group_program(group),
            "program_name": _group_program(group),
            "roll_number": row["roll_number"],
            "group_roll_number": row["roll_number"],
        })
    return students


@frappe.whitelist()
def mark_attendance(course_schedule, student_group, date, records):
    """Mark attendance for a class. `records` = [{student, status}] with
    statuses Present/Absent/Leave (v17 has no "Half Day"; the app maps it
    to Leave). Idempotent per (student, course_schedule)."""
    _require_role("Instructor", "System Manager")
    if not isinstance(records, list) or not records:
        frappe.throw(_("records must be a non-empty list of {student, status}"))
    valid = {"Present", "Absent", "Leave"}
    created = 0
    updated = 0
    for rec in records:
        student = rec.get("student")
        status = rec.get("status")
        if not student or status not in valid:
            frappe.throw(_("Invalid attendance record: {0}").format(rec))
        existing = frappe.db.get_value(
            "Student Attendance",
            {"student": student, "course_schedule": course_schedule},
            "name",
        )
        if existing:
            # Re-marking a class updates the existing record (education's
            # model is one attendance per student per schedule).
            doc = frappe.get_doc("Student Attendance", existing)
            doc.status = status
            doc.save(ignore_permissions=True)
            updated += 1
            continue
        frappe.get_doc({
            "doctype": "Student Attendance",
            "student": student,
            "student_name": frappe.db.get_value("Student", student, "student_name"),
            "student_group": student_group,
            "course_schedule": course_schedule,
            "date": date,
            "status": status,
        }).insert(ignore_permissions=True)
        created += 1
    return {"message": f"{created} created, {updated} updated"}


@frappe.whitelist()
def teacher_assignments():
    _require_role("Instructor", "System Manager")
    instructor = _current_instructor()
    plans = frappe.db.get_all(
        "Assessment Plan",
        filters={"examiner": instructor},
        fields=["name", "assessment_name", "course", "student_group", "examiner",
                "examiner_name", "schedule_date", "creation"],
        order_by="creation desc",
    )
    return [_shape_plan(p) for p in plans]


@frappe.whitelist()
def create_assignment(title, course, student_group, due_date, description=None, file_path=None):
    _require_role("Instructor", "System Manager")
    instructor = _current_instructor()
    if not (title and course and student_group and due_date):
        frappe.throw(_("Title, course, class and due date are required."))
    group = frappe.get_doc("Student Group", student_group)
    if not frappe.db.exists("Assessment Group", ASSESSMENT_GROUP_ROOT):
        frappe.throw(_("Seed the base records first (run seed_data.py)."))
    plan = frappe.get_doc({
        "doctype": "Assessment Plan",
        "student_group": student_group,
        "assessment_name": title,
        "assessment_group": ASSESSMENT_GROUP_ROOT,
        "grading_scale": GRADING_SCALE,
        "course": course,
        "program": group.program,
        "academic_year": _current_academic_year(),
        "schedule_date": due_date,
        "from_time": EVENING_START,
        "to_time": EVENING_END,
        "examiner": instructor,
        "maximum_assessment_score": 100,
        "assessment_criteria": [{"assessment_criteria": CRITERION, "maximum_score": 100}],
    })
    plan.insert(ignore_permissions=True)
    return _shape_plan(plan)


@frappe.whitelist()
def update_assignment(name, title=None, course=None, student_group=None, due_date=None,
                      description=None, file_path=None, clear_attachment=False):
    _require_role("Instructor", "System Manager")
    plan = frappe.get_doc("Assessment Plan", name)
    if plan.examiner != _current_instructor():
        frappe.throw(_("You can only edit your own assignments."), frappe.PermissionError)
    if title:
        plan.assessment_name = title
    if course:
        plan.course = course
    if student_group:
        plan.student_group = student_group
    if due_date:
        plan.schedule_date = due_date
    plan.save(ignore_permissions=True)
    return _shape_plan(plan)


@frappe.whitelist()
def delete_assignment(name):
    _require_role("Instructor", "System Manager")
    plan = frappe.get_doc("Assessment Plan", name)
    if plan.examiner != _current_instructor():
        frappe.throw(_("You can only delete your own assignments."), frappe.PermissionError)
    for sub in frappe.db.get_all("Student Submission", filters={"assessment_plan": name}, pluck="name"):
        frappe.delete_doc("Student Submission", sub, force=True, ignore_permissions=True)
    plan.delete(ignore_permissions=True)
    return {"message": "Deleted"}


@frappe.whitelist()
def assignment_submissions(assignment):
    _require_role("Instructor", "System Manager")
    plan = frappe.get_doc("Assessment Plan", assignment)
    return [_shape_submission(s) for s in _submissions_for_plan(assignment)]


@frappe.whitelist()
def grade_submission(submission, score, feedback=None):
    _require_role("Instructor", "System Manager")
    doc = frappe.get_doc("Student Submission", submission)
    try:
        score = flt(score)
    except Exception:
        frappe.throw(_("Score must be a number."))
    score = max(0.0, min(100.0, score))
    doc.score = score
    doc.feedback = feedback
    doc.status = "Graded"
    doc.graded_by = _current_instructor()
    doc.graded_at = datetime.datetime.now()
    doc.save(ignore_permissions=True)
    return _shape_submission(frappe.db.get_value(
        "Student Submission", submission,
        ["name", "assessment_plan", "student", "student_name", "status", "score",
         "feedback", "submission_file", "submitted_at", "graded_at", "graded_by"],
        as_dict=True,
    ))


@frappe.whitelist()
def unsubmit_submission(submission):
    role = _require_role("Instructor", "Student", "System Manager")
    doc = frappe.get_doc("Student Submission", submission)
    if role == "Student" and doc.student != _current_student():
        frappe.throw(_("You can only unsubmit your own work."), frappe.PermissionError)
    frappe.delete_doc("Student Submission", submission, force=True, ignore_permissions=True)
    return {"message": "Removed"}


@frappe.whitelist()
def delete_submission(submission):
    _require_role("Instructor", "System Manager")
    frappe.delete_doc("Student Submission", submission, force=True, ignore_permissions=True)
    return {"message": "Deleted"}


# --------------------------------------------------------------------------
# student
# --------------------------------------------------------------------------
@frappe.whitelist()
def my_attendance_summary():
    _require_role("Student")
    student = _current_student()
    # Only count days that have actually happened — future-dated records
    # (e.g. pre-marked classes later this week) must not inflate the
    # percentage or paint the calendar ahead of today.
    records = frappe.db.get_all(
        "Student Attendance",
        filters={"student": student, "date": ("<=", frappe.utils.today())},
        fields=["name", "student", "student_name", "student_group", "course_schedule",
                "date", "status"],
        order_by="date asc",
    )
    total = len(records)
    attended = 0
    course_stats = {}
    for r in records:
        course = frappe.db.get_value("Course Schedule", r.course_schedule, "course") if r.course_schedule else None
        key = course or "Other"
        bucket = course_stats.setdefault(key, {"total": 0, "attended": 0})
        bucket["total"] += 1
        if r.status in ("Present", "Leave"):
            bucket["attended"] += 1
            attended += 1
    course_wise = {
        (_course_name(c) or c): round(100 * v["attended"] / v["total"], 1)
        for c, v in course_stats.items()
    }
    overall = round(100 * attended / total, 1) if total else 0.0
    monthly = [
        {"date": str(r.date), "status": r.status}
        for r in records
    ]
    return {
        "overall_percentage": overall,
        "course_wise_percentage": course_wise,
        "monthly_attendance": monthly,
    }


@frappe.whitelist()
def my_attendance(course=None):
    _require_role("Student")
    student = _current_student()
    filters = {"student": student}
    if course:
        # Attendance rows link to a Course Schedule; the app filters by course.
        schedules = frappe.db.get_all(
            "Course Schedule", filters={"course": course}, pluck="name"
        )
        if not schedules:
            return []
        filters["course_schedule"] = ("in", schedules)
    filters["date"] = ("<=", frappe.utils.today())
    records = frappe.db.get_all(
        "Student Attendance",
        filters=filters,
        fields=["name", "student", "student_name", "student_group", "course_schedule",
                "date", "status"],
        order_by="date desc",
    )
    out = []
    for r in records:
        course_name = None
        if r.course_schedule:
            course_name = _course_name(
                frappe.db.get_value("Course Schedule", r.course_schedule, "course")
            )
        out.append({
            "name": r.name,
            "student": r.student,
            "student_name": r.student_name,
            "course_schedule": r.course_schedule,
            "course_name": course_name,
            "student_group": r.student_group,
            "student_group_name": _group_name(r.student_group),
            "student_attendance_date": str(r.date),
            "status": r.status,
            "remarks": None,
        })
    return out


@frappe.whitelist()
def my_assignments():
    _require_role("Student")
    student = _current_student()
    groups = frappe.db.get_all(
        "Student Group Student",
        filters={"student": student, "active": 1},
        pluck="parent",
    )
    if not groups:
        return []
    plans = frappe.db.get_all(
        "Assessment Plan",
        filters={"student_group": ("in", groups)},
        fields=["name", "assessment_name", "course", "student_group", "examiner",
                "examiner_name", "schedule_date", "from_time", "to_time", "creation"],
        order_by="creation desc",
    )
    return [_shape_plan(p, student=student) for p in plans]


@frappe.whitelist()
def my_attendance_month(year, month):
    """Attendance rows for one calendar month (for the calendar's month
    navigation). Rows after today are excluded so future days stay neutral."""
    _require_role("Student")
    student = _current_student()
    try:
        y, m = int(year), int(month)
        start = datetime.date(y, m, 1)
    except (TypeError, ValueError):
        frappe.throw(_("Invalid month."))
    if m == 12:
        end = datetime.date(y + 1, 1, 1)
    else:
        end = datetime.date(y, m + 1, 1)
    filters = {
        "student": student,
        "date": ["between", [str(start), str(end - datetime.timedelta(days=1))]],
    }
    records = frappe.db.get_all(
        "Student Attendance",
        filters=filters,
        fields=["date", "status", "course_schedule"],
        order_by="date asc",
    )
    today = frappe.utils.today()
    return [
        {
            "date": str(r.date),
            "status": r.status,
            "course": frappe.db.get_value("Course Schedule", r.course_schedule, "course")
            if r.course_schedule else None,
        }
        for r in records
        if str(r.date) <= today
    ]


@frappe.whitelist()
def assignments_on_date(date):
    """Assignments (Assessment Plans) scheduled on a specific date for the
    student's classes — powers the calendar's tap-a-day sheet."""
    _require_role("Student")
    student = _current_student()
    groups = frappe.db.get_all(
        "Student Group Student",
        filters={"student": student, "active": 1},
        pluck="parent",
    )
    if not groups:
        return []
    plans = frappe.db.get_all(
        "Assessment Plan",
        filters={"student_group": ("in", groups), "schedule_date": date},
        fields=["name", "assessment_name", "course", "student_group", "examiner",
                "examiner_name", "schedule_date", "from_time", "to_time", "creation"],
        order_by="creation asc",
    )
    return [_shape_plan(p, student=student) for p in plans]


@frappe.whitelist()
def submit_assignment(assignment, file_name=None, file_url=None):
    """Record a submission. `file_name` is the display name; `file_url` is an
    optional uploaded file's URL (real binary upload via submit_with_file)."""
    _require_role("Student")
    student = _current_student()
    plan = frappe.get_doc("Assessment Plan", assignment)
    group = plan.student_group
    if not frappe.db.exists("Student Group Student", {
        "parent": group, "student": student, "active": 1,
    }):
        frappe.throw(_("You are not a member of this assignment's class."), frappe.PermissionError)

    existing = frappe.db.get_value(
        "Student Submission",
        {"assessment_plan": assignment, "student": student},
        "name",
    )
    if existing:
        doc = frappe.get_doc("Student Submission", existing)
        if doc.status == "Graded":
            frappe.throw(_("This submission has already been graded."))
        doc.status = "Submitted"
        doc.submission_file = file_name or doc.submission_file
        doc.file_url = file_url or doc.file_url
        doc.submitted_at = datetime.datetime.now()
        doc.save(ignore_permissions=True)
        sub_name = doc.name
    else:
        sub = frappe.get_doc({
            "doctype": "Student Submission",
            "student": student,
            "student_name": frappe.db.get_value("Student", student, "student_name"),
            "assessment_plan": assignment,
            "course": plan.course,
            "student_group": group,
            "submission_file": file_name,
            "file_url": file_url,
            "submitted_at": datetime.datetime.now(),
            "status": "Submitted",
        })
        sub.insert(ignore_permissions=True)
        sub_name = sub.name

    rows = frappe.db.get_all(
        "Student Submission",
        filters={"name": sub_name},
        fields=["name", "assessment_plan", "student", "student_name", "status", "score",
                "feedback", "submission_file", "file_url", "submitted_at", "graded_at", "graded_by"],
    )
    return _shape_submission(rows[0])


@frappe.whitelist()
def submit_with_file(assignment):
    """Real binary upload: multipart `file` + `assignment` form fields.
    Saves the file via Frappe's file manager, links it to the submission."""
    import io

    from frappe.utils.file_manager import save_file

    _require_role("Student")
    student = _current_student()

    file = frappe.request.files.get("file")
    if not file or not file.filename:
        frappe.throw(_("No file uploaded."))

    file_name = file.filename
    content = file.read()
    if len(content) > 10 * 1024 * 1024:
        frappe.throw(_("File is too large (max 10 MB)."))

    doc = save_file(
        file_name,
        content,
        dt="Student Submission",
        dn=None,
        is_private=0,
    )

    result = submit_assignment(assignment=assignment, file_name=file_name, file_url=doc.file_url)
    return _shape_submission(frappe.db.get_value(
        "Student Submission", result["name"],
        ["name", "assessment_plan", "student", "student_name", "status", "score",
         "feedback", "submission_file", "file_url", "submitted_at", "graded_at", "graded_by"],
        as_dict=True,
    ))


# --------------------------------------------------------------------------
# admin
# --------------------------------------------------------------------------
@frappe.whitelist()
def admin_dashboard():
    _require_role("System Manager", "School Admin")
    with _elevated():
        schools = []
        teachers = []
        students = []
        classes = []

        for group in frappe.db.get_all(
            "Student Group",
            fields=["name", "student_group_name", "program"],
            order_by="student_group_name",
        ):
            program = group.program
            schools.append({
                "name": program,
                "school_name": program,
            })
            classes.append({
                "name": group.name,
                "student_group_name": group.student_group_name,
                "program": program,
                "program_name": program,
                "group_size": _group_size(group.name),
            })

        for instr in frappe.db.get_all(
            "Instructor",
            fields=["name", "instructor_name"],
            order_by="instructor_name",
        ):
            user_email = frappe.db.get_value(
                "User", {"full_name": instr.instructor_name}, "email"
            )
            teachers.append({
                "name": instr.instructor_name,
                "instructor_name": instr.instructor_name,
                "instructor_email": user_email,
                "email": user_email,
                "department": "Teaching",
                "classes": [],
            })

        for student in frappe.db.get_all(
            "Student",
            fields=["name", "student_name", "student_email_id", "gender", "date_of_birth"],
            order_by="student_name",
        ):
            memberships = frappe.db.get_all(
                "Student Group Student",
                filters={"student": student.name, "active": 1},
                fields=["parent", "group_roll_number"],
            )
            group = memberships[0]["parent"] if memberships else None
            roll = memberships[0]["group_roll_number"] if memberships else None
            program = _group_program(group) if group else None
            students.append({
                "name": student.name,
                "student_name": student.student_name,
                "student_email_id": student.student_email_id,
                "email": student.student_email_id,
                "gender": student.gender,
                "date_of_birth": str(student.date_of_birth) if student.date_of_birth else None,
                "student_group": group,
                "student_group_name": _group_name(group) if group else None,
                "program": program,
                "roll_number": roll,
                "group_roll_number": roll,
            })

        # De-duplicate schools (one per program).
        seen = set()
        unique_schools = []
        for s in schools:
            if s["name"] not in seen:
                seen.add(s["name"])
                unique_schools.append(s)

        school = unique_schools[0] if unique_schools else None
        return {
            "school": school,
            "schools": unique_schools,
            "teachers": teachers,
            "students": students,
            "classes": classes,
        }


# --------------------------------------------------------------------------
# teacher: per-course attendance detail
# --------------------------------------------------------------------------
@frappe.whitelist()
def course_attendance(course_schedule):
    """Attendance records for one course schedule, grouped per student
    (teacher's "attendance detail" view)."""
    _require_role("Instructor", "System Manager", "School Admin")
    with _elevated():
        schedule = frappe.get_doc("Course Schedule", course_schedule)
        records = frappe.db.get_all(
            "Student Attendance",
            filters={"course_schedule": course_schedule},
            fields=["student", "student_name", "date", "status"],
            order_by="student asc, date asc",
        )
        grouped = {}
        for r in records:
            grouped.setdefault(r.student, {"student_name": r.student_name, "records": []})
            grouped[r.student]["records"].append(
                {"date": str(r.date), "status": r.status}
            )
        students = []
        for student, data in grouped.items():
            total = len(data["records"])
            present = sum(1 for x in data["records"] if x["status"] in ("Present", "Leave"))
            students.append({
                "student": student,
                "student_name": data["student_name"],
                "percentage": round(100 * present / total, 1) if total else 0.0,
                "records": data["records"],
            })
        return {
            "course": schedule.course,
            "course_name": _course_name(schedule.course),
            "student_group": schedule.student_group,
            "student_group_name": _group_name(schedule.student_group),
            "instructor": schedule.instructor,
            "instructor_name": schedule.instructor_name,
            "room": schedule.room,
            "from_time": str(schedule.from_time) if schedule.from_time else None,
            "to_time": str(schedule.to_time) if schedule.to_time else None,
            "students": students,
        }


# --------------------------------------------------------------------------
# shared student detail (teacher/admin, and self for students)
# --------------------------------------------------------------------------
@frappe.whitelist()
def student_detail(student, course=None):
    """Attendance + grades for one student, shaped for the app's
    StudentDetailModel (teacher/admin view, or a student viewing self).

    When a teacher opens a student from a class roster, pass `course` so the
    view shows ONLY that subject's attendance + tests, not the whole school."""
    role = _require_role("Instructor", "Student", "System Manager", "School Admin")
    if role == "Student" and student != _current_student():
        frappe.throw(_("You can only view your own details."), frappe.PermissionError)

    with _elevated():
        info = frappe.db.get_value(
            "Student", student,
            ["student_name", "student_email_id", "gender", "date_of_birth", "city", "state", "country"],
            as_dict=True,
        ) or {}

        memberships = frappe.db.get_all(
            "Student Group Student",
            filters={"student": student, "active": 1},
            fields=["parent", "group_roll_number"],
        )
        group = memberships[0]["parent"] if memberships else None
        roll = memberships[0]["group_roll_number"] if memberships else None

        # restrict to one course when requested (teacher's subject view)
        course_schedules = None
        if course:
            course_schedules = frappe.db.get_all(
                "Course Schedule", filters={"course": course}, pluck="name"
            )

        # attendance
        att_filters = {"student": student}
        if course_schedules is not None:
            if not course_schedules:
                course_schedules = ["__none__"]
            att_filters["course_schedule"] = ("in", course_schedules)
        records = frappe.db.get_all(
            "Student Attendance",
            filters=att_filters,
            fields=["course_schedule", "status"],
        )
        total = len(records)
        attended = 0
        course_stats = {}
        for r in records:
            c = None
            if r.course_schedule:
                c = frappe.db.get_value("Course Schedule", r.course_schedule, "course")
            key = c or "Other"
            bucket = course_stats.setdefault(key, {"total": 0, "attended": 0})
            bucket["total"] += 1
            if r.status in ("Present", "Leave"):
                bucket["attended"] += 1
                attended += 1
        course_wise = {
            (_course_name(c) or c): round(100 * v["attended"] / v["total"], 1)
            for c, v in course_stats.items()
        }
        overall = round(100 * attended / total, 1) if total else 0.0

        # graded submissions → grade records (filtered to the course)
        sub_filters = {"student": student, "status": "Graded"}
        if course:
            plans = frappe.db.get_all(
                "Assessment Plan", filters={"course": course}, pluck="name"
            )
            if not plans:
                plans = ["__none__"]
            sub_filters["assessment_plan"] = ("in", plans)
        grades = []
        for sub in frappe.db.get_all(
            "Student Submission",
            filters=sub_filters,
            fields=["assessment_plan", "score", "feedback"],
            order_by="graded_at desc",
        ):
            plan = frappe.db.get_value(
                "Assessment Plan", sub.assessment_plan,
                ["assessment_name", "course", "schedule_date"], as_dict=True,
            ) if sub.assessment_plan else None
            grades.append({
                "assignment": sub.assessment_plan,
                "title": (plan.assessment_name if plan else sub.assessment_plan),
                "course_name": _course_name(plan.course) if plan else None,
                "due_date": str(plan.schedule_date) if plan and plan.schedule_date else None,
                "grade": flt(sub.score or 0),
                "feedback": sub.feedback,
                "status": "Graded",
            })

        return {
            "name": student,
            "student_name": info.get("student_name"),
            "student_email_id": info.get("student_email_id"),
            "gender": info.get("gender"),
            "date_of_birth": str(info.get("date_of_birth")) if info.get("date_of_birth") else None,
            "city": info.get("city"),
            "state": info.get("state"),
            "country": info.get("country"),
            "student_group": group,
            "student_group_name": _group_name(group) if group else None,
            "roll_number": roll,
            "group_roll_number": roll,
            "course": course,
            "course_name": _course_name(course) if course else None,
            "overall_attendance": overall,
            "course_wise_attendance": course_wise,
            "grades": grades,
        }


# --------------------------------------------------------------------------
# signup pickers (guest — public catalog data)
# --------------------------------------------------------------------------
@frappe.whitelist(allow_guest=True)
def programs():
    programs = frappe.db.get_all("Program", fields=["name", "program_name"], order_by="program_name")
    return [
        {"name": p["name"], "school_name": p["program_name"] or p["name"], "program": p["name"]}
        for p in programs
    ]


@frappe.whitelist(allow_guest=True)
def student_groups():
    groups = frappe.db.get_all(
        "Student Group",
        fields=["name", "student_group_name", "program"],
        order_by="student_group_name",
    )
    return [
        {
            "name": g["name"],
            "student_group_name": g["student_group_name"],
            "program": g["program"],
            "program_name": g["program"],
        }
        for g in groups
    ]


# --------------------------------------------------------------------------
# school profile (name / logo / contact info) — shown on dashboards & settings
# --------------------------------------------------------------------------
def _school_profile_doc():
    """The (single) School Profile doc, creating the row on first access so
    updates work even before the seed has run."""
    try:
        return frappe.get_single("School Profile")
    except frappe.DoesNotExistError:
        doc = frappe.new_doc("School Profile")
        doc.flags.ignore_permissions = True
        doc.school_name = "School"
        doc.insert(ignore_permissions=True)
        return doc


def _shape_school_profile(doc):
    return {
        "school_name": doc.school_name or "School",
        "motto": doc.motto or None,
        "logo_url": doc.logo or None,
        "contact_email": doc.contact_email or None,
        "contact_number": doc.contact_number or None,
        "website": doc.website or None,
        "address": doc.address or None,
    }


@frappe.whitelist(allow_guest=True)
def school_profile():
    """Public school profile — name, logo, contact email/number, address.
    Guest-accessible so the login/signup screens could brand themselves too."""
    try:
        return _shape_school_profile(_school_profile_doc())
    except frappe.DoesNotExistError:
        return _shape_school_profile(frappe.new_doc("School Profile"))


@frappe.whitelist()
def update_school_profile(
    school_name=None,
    motto=None,
    contact_email=None,
    contact_number=None,
    website=None,
    address=None,
):
    """School-admin only: edit the school's public profile fields."""
    _require_role("System Manager", "School Admin")
    with _elevated():
        doc = _school_profile_doc()
        if school_name is not None:
            doc.school_name = school_name
        if motto is not None:
            doc.motto = motto
        if contact_email is not None:
            doc.contact_email = contact_email
        if contact_number is not None:
            doc.contact_number = contact_number
        if website is not None:
            doc.website = website
        if address is not None:
            doc.address = address
        doc.save(ignore_permissions=True)
        return _shape_school_profile(doc)


@frappe.whitelist()
def upload_school_logo():
    """School-admin only: multipart `file` upload → sets the school logo.
    Returns the new logo_url (Frappe file URL)."""
    from frappe.utils.file_manager import save_file

    _require_role("System Manager", "School Admin")

    with _elevated():
        file = frappe.request.files.get("file")
        if not file or not file.filename:
            frappe.throw(_("No file uploaded."))
        content = file.read()
        if len(content) > 5 * 1024 * 1024:
            frappe.throw(_("Logo is too large (max 5 MB)."))
        if not file.filename.lower().endswith((".png", ".jpg", ".jpeg", ".webp", ".svg")):
            frappe.throw(_("Logo must be a PNG, JPG, WEBP or SVG image."))

        fdoc = save_file(
            file.filename,
            content,
            dt="School Profile",
            dn=None,
            is_private=0,
        )
        doc = _school_profile_doc()
        doc.logo = fdoc.file_url
        doc.save(ignore_permissions=True)
        return {"logo_url": fdoc.file_url}


# --------------------------------------------------------------------------
# student timetable / teachers / subjects
# --------------------------------------------------------------------------
@frappe.whitelist()
def my_timetable(week_start=None):
    """Student view: this week's timetable (daily grid data) plus the full
    list of subjects and teachers assigned to the student's groups.

    `week_start` is an ISO date (Monday). Defaults to the current week."""
    _require_role("Student")
    student = _current_student()

    groups = frappe.db.get_all(
        "Student Group Student",
        filters={"student": student, "active": 1},
        pluck="parent",
    )
    if not groups:
        return {"week_start": None, "week_end": None, "timetable": [], "teachers": [], "subjects": []}

    if week_start:
        start = datetime.date.fromisoformat(week_start)
    else:
        today = datetime.date.today()
        start = today - datetime.timedelta(days=today.weekday())  # this Monday
    end = start + datetime.timedelta(days=6)

    week_schedules = frappe.db.get_all(
        "Course Schedule",
        filters={
            "student_group": ("in", groups),
            "schedule_date": ("between", [str(start), str(end)]),
        },
        fields=["name", "course", "student_group", "instructor", "instructor_name",
                "schedule_date", "from_time", "to_time", "room"],
        order_by="schedule_date asc, from_time asc",
    )

    # all schedules for the student's groups (any date) → teachers + subjects
    all_schedules = frappe.db.get_all(
        "Course Schedule",
        filters={"student_group": ("in", groups)},
        fields=["course", "instructor", "instructor_name"],
    )
    teachers = {}
    subjects = {}
    for s in all_schedules:
        instr = s.instructor
        if instr:
            t = teachers.setdefault(
                instr,
                {"name": instr, "instructor_name": s.instructor_name or instr, "courses": []},
            )
            if s.course and s.course not in t["courses"]:
                t["courses"].append(s.course)
        if s.course:
            sub = subjects.setdefault(
                s.course,
                {"course": s.course, "course_name": _course_name(s.course) or s.course, "teachers": []},
            )
            if instr and instr not in sub["teachers"]:
                sub["teachers"].append(instr)

    def _shape_teacher(t):
        return {
            "name": t["name"],
            "instructor_name": t["instructor_name"],
            "courses": [
                {"course": c, "course_name": _course_name(c) or c} for c in t["courses"]
            ],
        }

    return {
        "week_start": str(start),
        "week_end": str(end),
        "timetable": [
            {
                "name": s.name,
                "date": str(s.schedule_date),
                "weekday": datetime.date.fromisoformat(str(s.schedule_date)).weekday(),
                "from_time": str(s.from_time) if s.from_time else None,
                "to_time": str(s.to_time) if s.to_time else None,
                "course": s.course,
                "course_name": _course_name(s.course) or s.course,
                "room": s.room,
                "instructor": s.instructor,
                "instructor_name": s.instructor_name or s.instructor,
                "student_group": s.student_group,
                "student_group_name": _group_name(s.student_group),
            }
            for s in week_schedules
        ],
        "teachers": [_shape_teacher(t) for t in teachers.values()],
        "subjects": [
            {
                "course": s["course"],
                "course_name": s["course_name"],
                "teachers": [
                    {
                        "name": instr,
                        "instructor_name": teachers.get(instr, {}).get("instructor_name") or instr,
                    }
                    for instr in s["teachers"]
                ],
            }
            for s in subjects.values()
        ],
    }
