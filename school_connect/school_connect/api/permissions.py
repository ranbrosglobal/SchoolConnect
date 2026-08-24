import frappe
from frappe import _


def student_attendance_permission(doc, ptype, user):
    """
    Permission check for Student Attendance.
    - Students can only see their own attendance
    - Instructors can see attendance for their classes
    - Admins/School Admins can see all
    """
    if not user:
        user = frappe.session.user

    # Get user roles
    roles = frappe.get_roles(user)

    # Admin has full access
    if "System Manager" in roles or "School Admin" in roles:
        return True

    # Student can only see their own
    if "Student" in roles:
        student = frappe.get_all(
            "Student",
            filters={"student_email_id": user, "name": doc.student},
            limit=1,
        )
        return len(student) > 0

    # Instructor can see attendance for their courses
    if "Instructor" in roles:
        instructor = frappe.get_all(
            "Instructor",
            filters={"instructor_email": user},
            fields=["name"],
            limit=1,
        )
        if instructor:
            # Check if the course schedule belongs to this instructor
            if doc.course_schedule:
                schedule = frappe.get_all(
                    "Course Schedule",
                    filters={
                        "name": doc.course_schedule,
                        "instructor": instructor[0].name,
                    },
                    limit=1,
                )
                return len(schedule) > 0

    return False


def assignment_permission(doc, ptype, user):
    """
    Permission check for Assignment.
    - Instructors can create/edit their own assignments
    - Students can only read assignments for their group
    - Admins have full access
    """
    if not user:
        user = frappe.session.user

    roles = frappe.get_roles(user)

    # Admin has full access
    if "System Manager" in roles or "School Admin" in roles:
        return True

    # Instructor can manage their assignments
    if "Instructor" in roles:
        instructor = frappe.get_all(
            "Instructor",
            filters={"instructor_email": user, "name": doc.instructor},
            limit=1,
        )
        return len(instructor) > 0

    # Students can only read
    if "Student" in roles:
        if ptype == "read":
            student = frappe.get_all(
                "Student",
                filters={"student_email_id": user},
                fields=["student_group"],
                limit=1,
            )
            if student and doc.student_group:
                return student[0].student_group == doc.student_group
        return False

    return False


def assignment_submission_permission(doc, ptype, user):
    """
    Permission check for Assignment Submission.
    - Students can only see/submit their own
    - Instructors can see submissions for their assignments
    - Admins have full access
    """
    if not user:
        user = frappe.session.user

    roles = frappe.get_roles(user)

    # Admin has full access
    if "System Manager" in roles or "School Admin" in roles:
        return True

    # Student can only see/submit their own
    if "Student" in roles:
        student = frappe.get_all(
            "Student",
            filters={"student_email_id": user, "name": doc.student},
            limit=1,
        )
        return len(student) > 0

    # Instructor can see submissions for their assignments
    if "Instructor" in roles:
        instructor = frappe.get_all(
            "Instructor",
            filters={"instructor_email": user},
            fields=["name"],
            limit=1,
        )
        if instructor:
            assignment = frappe.get_all(
                "Assignment",
                filters={
                    "name": doc.assignment,
                    "instructor": instructor[0].name,
                },
                limit=1,
            )
            return len(assignment) > 0

    return False
