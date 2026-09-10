import frappe
from frappe import _


@frappe.whitelist()
def get_my_classes():
    """
    Get classes assigned to the current teacher (Instructor).
    Returns Course Schedule entries where instructor = current user.
    """
    # Get current user's instructor record
    instructor = frappe.get_all(
        "Instructor",
        filters={"instructor_email": frappe.session.user},
        fields=["name"],
        limit=1,
    )

    if not instructor:
        frappe.throw(_("No instructor record found for current user"))

    instructor_id = instructor[0].name

    # Get course schedules for this instructor
    schedules = frappe.get_all(
        "Course Schedule",
        filters={"instructor": instructor_id},
        fields=[
            "name",
            "course",
            "course_name",
            "student_group",
            "student_group_name",
            "instructor",
            "instructor_name",
            "schedule_date",
            "from_time",
            "to_time",
            "room",
            "school",
        ],
        order_by="schedule_date desc",
    )

    return schedules


@frappe.whitelist()
def get_class_students(course_schedule):
    """
    Get students in a specific class (Course Schedule).
    """
    # Get the student group from course schedule
    schedule = frappe.get_doc("Course Schedule", course_schedule)

    if not schedule.student_group:
        frappe.throw(_("No student group linked to this course schedule"))

    # Get students in the student group (with roll numbers)
    students = frappe.get_all(
        "Student Group Student",
        filters={"parent": schedule.student_group},
        fields=["student", "student_name", "group_roll_number"],
        order_by="group_roll_number asc",
    )

    # Get full student details
    student_list = []
    for s in students:
        student_doc = frappe.get_all(
            "Student",
            filters={"name": s.student},
            fields=[
                "name",
                "student_name",
                "student_email_id",
                "school",
                "school_name",
                "student_group",
                "gender",
            ],
            limit=1,
        )
        if student_doc:
            student_doc[0]["roll_number"] = s.group_roll_number or ""
            student_list.append(student_doc[0])

    return student_list


@frappe.whitelist()
def mark_attendance(course_schedule, student_group, date, attendance):
    """
    Bulk mark attendance for a class.
    attendance: list of dicts with student and status
    """
    # Verify instructor has access to this course schedule
    schedule = frappe.get_doc("Course Schedule", course_schedule)

    instructor = frappe.get_all(
        "Instructor",
        filters={"instructor_email": frappe.session.user},
        fields=["name"],
        limit=1,
    )

    if not instructor or schedule.instructor != instructor[0].name:
        frappe.throw(_("You don't have permission to mark attendance for this class"))

    # Parse attendance data
    if isinstance(attendance, str):
        attendance = frappe.parse_json(attendance)

    created = 0
    updated = 0

    for record in attendance:
        student = record.get("student")
        status = record.get("status")

        if not student or not status:
            continue

        # Check if attendance already exists
        existing = frappe.get_all(
            "Student Attendance",
            filters={
                "student": student,
                "course_schedule": course_schedule,
                "student_attendance_date": date,
            },
            fields=["name"],
            limit=1,
        )

        if existing:
            # Update existing attendance
            frappe.db.set_value(
                "Student Attendance", existing[0].name, "status", status
            )
            updated += 1
        else:
            # Create new attendance
            attendance_doc = frappe.get_doc(
                {
                    "doctype": "Student Attendance",
                    "student": student,
                    "student_group": student_group,
                    "course_schedule": course_schedule,
                    "student_attendance_date": date,
                    "status": status,
                }
            )
            attendance_doc.insert(ignore_permissions=True)
            created += 1

    frappe.db.commit()

    return {
        "message": f"Attendance marked: {created} created, {updated} updated",
        "created": created,
        "updated": updated,
    }


@frappe.whitelist()
def get_attendance_report(course_schedule, date=None):
    """
    Get attendance report for a course schedule on a specific date.
    """
    filters = {"course_schedule": course_schedule}

    if date:
        filters["student_attendance_date"] = date
    else:
        # Default to today
        filters["student_attendance_date"] = frappe.utils.today()

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
    )

    return attendance


def _get_current_instructor():
    """Get the Instructor record for the current user."""
    instructor = frappe.get_all(
        "Instructor",
        filters={"instructor_email": frappe.session.user},
        fields=["name", "school"],
        limit=1,
    )
    if not instructor:
        frappe.throw(_("No instructor record found for current user"))
    return instructor[0]


@frappe.whitelist()
def get_my_assignments():
    """
    Get assignments created by the current instructor,
    with submission statistics (total students, submitted, graded).
    """
    instructor = _get_current_instructor()

    assignments = frappe.get_all(
        "Assignment",
        filters={"instructor": instructor.name},
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

    if not assignments:
        return []

    assignment_names = [a.name for a in assignments]

    # All submissions for these assignments (single query)
    submissions = frappe.get_all(
        "Assignment Submission",
        filters={"assignment": ["in", assignment_names]},
        fields=["assignment", "grade"],
    )

    # Student group sizes (single query)
    group_names = {a.student_group for a in assignments if a.student_group}
    group_sizes = {}
    if group_names:
        students = frappe.get_all(
            "Student Group Student",
            filters={"parent": ["in", list(group_names)], "active": 1},
            fields=["parent"],
        )
        for s in students:
            group_sizes[s.parent] = group_sizes.get(s.parent, 0) + 1

    for a in assignments:
        a["total_students"] = group_sizes.get(a.student_group, 0)
        a["submitted_count"] = len(
            [s for s in submissions if s.assignment == a.name]
        )
        a["graded_count"] = len(
            [
                s
                for s in submissions
                if s.assignment == a.name and s.grade is not None
            ]
        )

    return assignments


@frappe.whitelist()
def create_assignment(
    title,
    course,
    student_group,
    due_date,
    description=None,
    attachment=None,
    attachment_name=None,
):
    """
    Create a new assignment for a class the instructor teaches.
    """
    instructor = _get_current_instructor()

    # Verify the instructor teaches this course for this student group
    schedule = frappe.get_all(
        "Course Schedule",
        filters={
            "instructor": instructor.name,
            "course": course,
            "student_group": student_group,
        },
        limit=1,
    )
    if not schedule:
        frappe.throw(
            _("You can only create assignments for classes assigned to you")
        )

    doc = frappe.get_doc(
        {
            "doctype": "Assignment",
            "title": title,
            "course": course,
            "student_group": student_group,
            "instructor": instructor.name,
            "due_date": due_date,
            "description": description,
            "attachment": attachment,
            "attachment_name": attachment_name,
        }
    )
    doc.insert()
    frappe.db.commit()

    return {"name": doc.name, "title": doc.title}


@frappe.whitelist()
def update_assignment(
    name,
    title,
    course,
    student_group,
    due_date,
    description=None,
    attachment=None,
    attachment_name=None,
):
    """
    Update an assignment created by the current instructor.
    """
    instructor = _get_current_instructor()

    doc = frappe.get_doc("Assignment", name)
    if doc.instructor != instructor.name:
        frappe.throw(_("You can only edit assignments you created"))

    # Verify the instructor still teaches this course for this student group
    schedule = frappe.get_all(
        "Course Schedule",
        filters={
            "instructor": instructor.name,
            "course": course,
            "student_group": student_group,
        },
        limit=1,
    )
    if not schedule:
        frappe.throw(
            _("You can only edit assignments for classes assigned to you")
        )

    doc.title = title
    doc.course = course
    doc.student_group = student_group
    doc.due_date = due_date
    doc.description = description
    # attachment is None when unchanged; empty string means clear the file
    if attachment is not None:
        doc.attachment = attachment or None
        doc.attachment_name = attachment_name or None
    doc.save()
    frappe.db.commit()

    return {"name": doc.name, "title": doc.title}


@frappe.whitelist()
def delete_assignment(name):
    """
    Delete an assignment created by the current instructor,
    along with its submissions.
    """
    instructor = _get_current_instructor()

    doc = frappe.get_doc("Assignment", name)
    if doc.instructor != instructor.name:
        frappe.throw(_("You can only delete assignments you created"))

    # Remove submissions first to avoid orphaned records
    submissions = frappe.get_all(
        "Assignment Submission",
        filters={"assignment": name},
        fields=["name"],
    )
    for s in submissions:
        frappe.delete_doc(
            "Assignment Submission", s.name, force=True, ignore_permissions=True
        )
    frappe.delete_doc("Assignment", name, force=True, ignore_permissions=True)
    frappe.db.commit()

    return {"name": name}


@frappe.whitelist()
def get_assignment_submissions(assignment):
    """
    Get all submissions for an assignment, with student details and roll numbers.
    Only the instructor who created the assignment can view them.
    """
    instructor = _get_current_instructor()

    assignment_doc = frappe.get_all(
        "Assignment",
        filters={"name": assignment, "instructor": instructor.name},
        fields=["name", "student_group"],
        limit=1,
    )
    if not assignment_doc:
        frappe.throw(
            _("Assignment not found or you don't have permission to view it")
        )

    submissions = frappe.get_all(
        "Assignment Submission",
        filters={"assignment": assignment},
        fields=[
            "name",
            "assignment",
            "student",
            "submitted_at",
            "file",
            "file_name",
            "grade",
            "feedback",
            "status",
        ],
        order_by="submitted_at asc",
    )

    # Student details
    student_ids = [s.student for s in submissions if s.student]
    students = {}
    if student_ids:
        student_records = frappe.get_all(
            "Student",
            filters={"name": ["in", student_ids]},
            fields=["name", "student_name", "student_email_id", "gender"],
        )
        students = {s.name: s for s in student_records}

    # Roll numbers from the student group enrollment
    roll_numbers = {}
    if assignment_doc[0].student_group:
        enrollments = frappe.get_all(
            "Student Group Student",
            filters={"parent": assignment_doc[0].student_group},
            fields=["student", "group_roll_number"],
        )
        roll_numbers = {
            e.student: e.group_roll_number for e in enrollments
        }

    for s in submissions:
        student = students.get(s.student)
        s["student_name"] = (
            student.student_name if student else (s.get("student_name") or "")
        )
        s["student_email_id"] = (
            student.student_email_id if student else ""
        )
        s["roll_number"] = roll_numbers.get(s.student) or ""

    return submissions


@frappe.whitelist()
def get_student_details(student, student_group=None):
    """
    Get a student's profile, roll number, attendance percentage and grades.
    - Instructors can view students enrolled in their classes.
    - School Admins can view students in their school.
    - System Managers can view any student.
    """
    roles = frappe.get_roles(frappe.session.user)

    student_docs = frappe.get_all(
        "Student",
        filters={"name": student},
        fields=[
            "name",
            "student_name",
            "student_email_id",
            "gender",
            "school",
            "school_name",
        ],
        limit=1,
        ignore_permissions=True,
    )
    if not student_docs:
        frappe.throw(_("Student not found"))
    student_doc = student_docs[0]

    # ---- Permission check ----
    if "Instructor" in roles:
        instructor = frappe.get_all(
            "Instructor",
            filters={"instructor_email": frappe.session.user},
            fields=["name"],
            limit=1,
        )
        if not instructor:
            frappe.throw(_("No instructor record found for current user"))

        # Student groups this instructor teaches
        schedules = frappe.get_all(
            "Course Schedule",
            filters={"instructor": instructor[0].name},
            fields=["student_group"],
            ignore_permissions=True,
        )
        groups = [s.student_group for s in schedules if s.student_group]

        if student_group:
            if student_group not in groups:
                frappe.throw(_("You don't have permission to view this student"))
        else:
            enrolled = frappe.get_all(
                "Student Group Student",
                filters={"student": student, "parent": ["in", groups]},
                limit=1,
                ignore_permissions=True,
            )
            if not enrolled:
                frappe.throw(_("You don't have permission to view this student"))

    elif "School Admin" in roles:
        admin_school = None
        if frappe.db.has_column("User", "custom_school"):
            admin_school = frappe.db.get_value(
                "User", frappe.session.user, "custom_school"
            )
        if not admin_school:
            frappe.throw(
                _("No school is linked to your account. Please contact the administrator.")
            )
        if student_doc.school and student_doc.school != admin_school:
            frappe.throw(_("You don't have permission to view this student"))

    elif "System Manager" not in roles and "Administrator" not in roles:
        frappe.throw(_("You don't have permission to view this student"))

    # ---- Roll number & student group ----
    roll_number = ""
    group_name = ""
    if student_group:
        enrollment = frappe.get_all(
            "Student Group Student",
            filters={"parent": student_group, "student": student},
            fields=["group_roll_number"],
            limit=1,
            ignore_permissions=True,
        )
        if enrollment:
            roll_number = enrollment[0].group_roll_number or ""
        sg = frappe.get_all(
            "Student Group",
            filters={"name": student_group},
            fields=["student_group_name"],
            limit=1,
            ignore_permissions=True,
        )
        if sg:
            group_name = sg[0].student_group_name
    else:
        enrollment = frappe.get_all(
            "Student Group Student",
            filters={"student": student, "active": 1},
            fields=["parent", "group_roll_number"],
            limit=1,
            ignore_permissions=True,
        )
        if enrollment:
            roll_number = enrollment[0].group_roll_number or ""
            sg = frappe.get_all(
                "Student Group",
                filters={"name": enrollment[0].parent},
                fields=["student_group_name"],
                limit=1,
                ignore_permissions=True,
            )
            if sg:
                group_name = sg[0].student_group_name

    # ---- Attendance summary ----
    attendance = frappe.get_all(
        "Student Attendance",
        filters={"student": student},
        fields=["status", "course_name"],
        ignore_permissions=True,
    )
    total = len(attendance)
    present = len([a for a in attendance if a.status in ["Present", "Half Day"]])
    overall = (present / total * 100) if total > 0 else 0

    course_wise = {}
    for a in attendance:
        course = a.course_name or "Unknown"
        if course not in course_wise:
            course_wise[course] = {"total": 0, "present": 0}
        course_wise[course]["total"] += 1
        if a.status in ["Present", "Half Day"]:
            course_wise[course]["present"] += 1
    course_wise_pct = {
        course: round(d["present"] / d["total"] * 100, 1)
        for course, d in course_wise.items()
    }

    # ---- Grades ----
    submissions = frappe.get_all(
        "Assignment Submission",
        filters={"student": student},
        fields=["assignment", "grade", "feedback", "status"],
        order_by="submitted_at desc",
        ignore_permissions=True,
    )
    assignment_names = [s.assignment for s in submissions if s.assignment]
    assignments_map = {}
    if assignment_names:
        assignments = frappe.get_all(
            "Assignment",
            filters={"name": ["in", assignment_names]},
            fields=["name", "title", "course_name", "student_group", "due_date"],
            ignore_permissions=True,
        )
        assignments_map = {a.name: a for a in assignments}

    grades = []
    for s in submissions:
        a = assignments_map.get(s.assignment)
        if student_group and a and a.student_group != student_group:
            continue
        grades.append(
            {
                "assignment": s.assignment,
                "title": a.title if a else s.assignment,
                "course_name": a.course_name if a else "",
                "due_date": str(a.due_date) if a and a.due_date else None,
                "grade": s.grade,
                "feedback": s.feedback,
                "status": s.status,
            }
        )

    return {
        "name": student_doc.name,
        "student_name": student_doc.student_name,
        "student_email_id": student_doc.student_email_id,
        "gender": student_doc.gender,
        "school": student_doc.school,
        "school_name": student_doc.school_name,
        "student_group": student_group,
        "student_group_name": group_name,
        "roll_number": roll_number,
        "overall_attendance": round(overall, 1),
        "course_wise_attendance": course_wise_pct,
        "grades": grades,
    }


@frappe.whitelist()
def grade_submission(submission, grade, feedback=None):
    """
    Grade a student's assignment submission.
    Only the instructor who created the assignment can grade it.
    """
    instructor = _get_current_instructor()

    submission_doc = frappe.get_doc("Assignment Submission", submission)
    assignment = frappe.get_doc("Assignment", submission_doc.assignment)

    if assignment.instructor != instructor.name:
        frappe.throw(
            _("You don't have permission to grade this submission")
        )

    try:
        grade_value = float(grade)
    except (TypeError, ValueError):
        frappe.throw(_("Grade must be a number between 0 and 100"))

    if grade_value < 0 or grade_value > 100:
        frappe.throw(_("Grade must be between 0 and 100"))

    submission_doc.grade = grade_value
    submission_doc.feedback = feedback
    submission_doc.status = "Graded"
    submission_doc.save()
    frappe.db.commit()

    return {
        "name": submission_doc.name,
        "grade": submission_doc.grade,
        "status": submission_doc.status,
    }


@frappe.whitelist()
def unsubmit_submission(submission):
    """
    Return a student's submission so they can revise and resubmit.
    Clears the grade and feedback; only the assignment's instructor can do this.
    """
    instructor = _get_current_instructor()

    submission_doc = frappe.get_doc("Assignment Submission", submission)
    assignment = frappe.get_doc("Assignment", submission_doc.assignment)

    if assignment.instructor != instructor.name:
        frappe.throw(_("You don't have permission to unsubmit this submission"))

    submission_doc.status = "Returned"
    submission_doc.grade = None
    submission_doc.feedback = None
    submission_doc.save()
    frappe.db.commit()

    return {
        "name": submission_doc.name,
        "status": submission_doc.status,
    }


@frappe.whitelist()
def delete_submission(submission):
    """
    Delete a student's submission entirely so they can submit again.
    Only the assignment's instructor can do this.
    """
    instructor = _get_current_instructor()

    submission_doc = frappe.get_doc("Assignment Submission", submission)
    assignment = frappe.get_doc("Assignment", submission_doc.assignment)

    if assignment.instructor != instructor.name:
        frappe.throw(_("You don't have permission to delete this submission"))

    frappe.delete_doc(
        "Assignment Submission", submission, force=True, ignore_permissions=True
    )
    frappe.db.commit()

    return {"name": submission}

