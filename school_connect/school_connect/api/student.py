import frappe
from frappe import _
from frappe.utils import today, getdate, add_months


@frappe.whitelist()
def get_my_attendance_summary():
    """
    Get attendance summary for the current student.
    Includes overall percentage, course-wise percentage, and monthly data.
    """
    # Get current student
    student = frappe.get_all(
        "Student",
        filters={"student_email_id": frappe.session.user},
        fields=["name", "school", "student_group"],
        limit=1,
    )

    if not student:
        frappe.throw(_("No student record found for current user"))

    student_id = student[0].name

    # Get all attendance records
    all_attendance = frappe.get_all(
        "Student Attendance",
        filters={"student": student_id},
        fields=["name", "status", "course_name", "student_attendance_date"],
    )

    # Calculate overall percentage
    total = len(all_attendance)
    present = len(
        [a for a in all_attendance if a.status in ["Present", "Half Day"]]
    )
    overall_percentage = (present / total * 100) if total > 0 else 0

    # Calculate course-wise percentage
    course_attendance = {}
    for a in all_attendance:
        course = a.course_name or "Unknown"
        if course not in course_attendance:
            course_attendance[course] = {"total": 0, "present": 0}
        course_attendance[course]["total"] += 1
        if a.status in ["Present", "Half Day"]:
            course_attendance[course]["present"] += 1

    course_wise_percentage = {}
    for course, data in course_attendance.items():
        course_wise_percentage[course] = (
            (data["present"] / data["total"] * 100) if data["total"] > 0 else 0
        )

    # Get current month attendance
    current_month_start = getdate(today()).replace(day=1)
    monthly_attendance = []
    for a in all_attendance:
        if a.student_attendance_date and getdate(a.student_attendance_date) >= current_month_start:
            monthly_attendance.append(
                {
                    "date": str(a.student_attendance_date),
                    "status": a.status,
                }
            )

    return {
        "overall_percentage": round(overall_percentage, 1),
        "course_wise_percentage": course_wise_percentage,
        "monthly_attendance": monthly_attendance,
    }


@frappe.whitelist()
def get_my_attendance(course=None):
    """
    Get attendance records for the current student.
    Optionally filter by course.
    """
    student = frappe.get_all(
        "Student",
        filters={"student_email_id": frappe.session.user},
        fields=["name"],
        limit=1,
    )

    if not student:
        frappe.throw(_("No student record found for current user"))

    filters = {"student": student[0].name}

    if course:
        filters["course"] = course

    attendance = frappe.get_all(
        "Student Attendance",
        filters=filters,
        fields=[
            "name",
            "student",
            "student_name",
            "course_schedule",
            "course_name",
            "student_group",
            "student_group_name",
            "student_attendance_date",
            "status",
            "remarks",
        ],
        order_by="student_attendance_date desc",
    )

    return attendance


@frappe.whitelist()
def get_my_assignments():
    """
    Get assignments for the current student.
    Based on student's enrolled courses and student group.
    """
    student = frappe.get_all(
        "Student",
        filters={"student_email_id": frappe.session.user},
        fields=["name", "student_group", "school"],
        limit=1,
    )

    if not student:
        frappe.throw(_("No student record found for current user"))

    student_id = student[0].name
    student_group = student[0].student_group
    school = student[0].school

    # Get assignments for student's group or courses
    filters = {}

    if student_group:
        filters["student_group"] = student_group
    elif school:
        filters["school"] = school

    assignments = frappe.get_all(
        "Assignment",
        filters=filters,
        fields=[
            "name",
            "title",
            "description",
            "course",
            "course_name",
            "student_group",
            "student_group_name",
            "instructor",
            "instructor_name",
            "due_date",
            "creation",
            "attachment",
            "attachment_name",
        ],
        order_by="due_date asc",
    )

    # Get submission status for each assignment
    for assignment in assignments:
        submission = frappe.get_all(
            "Assignment Submission",
            filters={
                "assignment": assignment.name,
                "student": student_id,
            },
            fields=[
                "name",
                "grade",
                "feedback",
                "status",
                "file",
                "file_name",
                "submitted_at",
            ],
            limit=1,
        )
        # A returned submission is not "submitted" — the student must redo it
        assignment["submitted"] = (
            len(submission) > 0 and submission[0].status != "Returned"
        )
        if submission:
            assignment["submission"] = submission[0]
        else:
            assignment["submission"] = None

    return assignments


@frappe.whitelist()
def submit_assignment(assignment, file):
    """
    Submit an assignment for the current student with an attached file.
    Enforces the assignment's due-date deadline and class enrollment.
    """
    student = frappe.get_all(
        "Student",
        filters={"student_email_id": frappe.session.user},
        fields=["name"],
        limit=1,
    )
    if not student:
        frappe.throw(_("No student record found for current user"))
    student_id = student[0].name

    assignment_doc = frappe.get_doc("Assignment", assignment)

    # Student must be enrolled in the assignment's student group
    if assignment_doc.student_group:
        enrolled = frappe.get_all(
            "Student Group Student",
            filters={
                "parent": assignment_doc.student_group,
                "student": student_id,
            },
            limit=1,
        )
        if not enrolled:
            frappe.throw(
                _("You are not enrolled in the class for this assignment")
            )

    # If the teacher returned the submission, the student may resubmit
    # (even after the original deadline) by updating the existing record.
    existing = frappe.get_all(
        "Assignment Submission",
        filters={"assignment": assignment, "student": student_id},
        fields=["name", "status"],
        limit=1,
    )
    resubmitting = bool(existing) and existing[0].status == "Returned"

    if existing and not resubmitting:
        frappe.throw(_("You have already submitted this assignment"))

    # Due-date deadline for new submissions (returned work can be resubmitted)
    if (
        not resubmitting
        and assignment_doc.due_date
        and today() > assignment_doc.due_date
    ):
        frappe.throw(
            _(
                "The submission deadline for this assignment has passed "
                "(was due on {0})."
            ).format(assignment_doc.due_date)
        )

    if resubmitting:
        doc = frappe.get_doc("Assignment Submission", existing[0].name)
        doc.file = file
        doc.file_name = file.split("/")[-1]
        doc.submitted_at = frappe.utils.now_datetime()
        doc.status = "Submitted"
        doc.grade = None
        doc.feedback = None
        doc.save(ignore_permissions=True)
    else:
        doc = frappe.get_doc(
            {
                "doctype": "Assignment Submission",
                "assignment": assignment,
                "student": student_id,
                "file": file,
            }
        )
        doc.insert(ignore_permissions=True)
    frappe.db.commit()

    return {
        "name": doc.name,
        "assignment": assignment,
        "student": student_id,
        "file": doc.file,
        "file_name": doc.file_name,
        "submitted_at": str(doc.submitted_at),
        "status": doc.status,
    }


@frappe.whitelist()
def get_my_profile():
    """
    Get current student's profile information.
    """
    student = frappe.get_all(
        "Student",
        filters={"student_email_id": frappe.session.user},
        fields=[
            "name",
            "student_name",
            "student_email_id",
            "school",
            "school_name",
            "student_group",
            "gender",
            "date_of_birth",
        ],
        limit=1,
    )

    if not student:
        frappe.throw(_("No student record found for current user"))

    return student[0]
