#!/usr/bin/env python3
"""
seed_data.py — Seed real data into the local Frappe Education bench (Phase 2).

Creates an idempotent, realistic dataset so every Flutter screen has live rows:

  Academic Year / Term, Assessment Group(s), Grading Scale, Assessment Criteria,
  Rooms, Programs, Courses, Users (teachers + students, with passwords),
  Instructors, Students, Student Groups (classes + roll numbers + instructors),
  Program Enrollments, Course Schedules, Student Attendance (last 15 weekdays),
  Assessment Plans (assignments), Assessment Results (grades + comments).

Run (plain Python — NOT `bench console`, which is unreliable):

  ~/Documents/frappe/frappe-bench/env/bin/python seed_data.py

Environment overrides:
  FRAPPE_BENCH_DIR   (default ~/Documents/frappe/frappe-bench)
  FRAPPE_SITE        (default library.localhost)

Safe to re-run: every record is looked up before creation.
"""

import datetime
import os
import sys

BENCH_DIR = os.environ.get("FRAPPE_BENCH_DIR", os.path.expanduser("~/Documents/frappe/frappe-bench"))
SITE = os.environ.get("FRAPPE_SITE", "library.localhost")
SITES_PATH = os.path.join(BENCH_DIR, "sites")

import frappe  # noqa: E402  (frappe resolves from the bench venv)
from erpnext.setup.doctype.holiday_list.holiday_list import is_holiday  # noqa: E402

ACADEMIC_YEAR = "2026-2027"
TERM = "Term 1"

ROOMS = ["Room 101", "Room 102", "Computer Lab 1"]

PROGRAMS = {
    "Grade 8": ["Mathematics", "Science", "English", "Social Studies", "Computer Science"],
    "Grade 9": ["Mathematics", "Science", "English", "Social Studies", "Computer Science"],
}

# (first, last, email, gender, dob, program, group)
STUDENTS = [
    ("Alex", "Smith", "alex.smith@school.com", "Male", "2012-04-12", "Grade 8", "Grade 8 - A"),
    ("Emma", "Wilson", "emma.wilson@school.com", "Female", "2012-07-03", "Grade 8", "Grade 8 - A"),
    ("Michael", "Brown", "michael.brown@school.com", "Male", "2012-01-25", "Grade 8", "Grade 8 - A"),
    ("Sophia", "Taylor", "sophia.taylor@school.com", "Female", "2012-09-18", "Grade 8", "Grade 8 - A"),
    ("James", "Miller", "james.miller@school.com", "Male", "2012-11-02", "Grade 8", "Grade 8 - B"),
    ("Jessica", "Davis", "jessica.davis@school.com", "Female", "2012-05-29", "Grade 8", "Grade 8 - B"),
    ("Thomas", "Gonzalez", "thomas.gonzalez@school.com", "Male", "2013-02-14", "Grade 9", "Grade 9 - A"),
    ("Barbara", "Smith", "barbara.smith@school.com", "Female", "2013-06-21", "Grade 9", "Grade 9 - A"),
    ("Patricia", "Hernandez", "patricia.hernandez@school.com", "Female", "2013-03-08", "Grade 9", "Grade 9 - A"),
    ("David", "Garcia", "david.garcia@school.com", "Male", "2013-08-30", "Grade 9", "Grade 9 - A"),
]

# (full_name, email, roles) — Academics User is education's teacher role
# (full CRUD on schedules/attendance/assessments); Instructor is limited.
USERS = [
    ("Mr. Robert Johnson", "robert.johnson@school.com", ["Instructor", "Academics User"]),
    ("Ms. Emily Davis", "emily.davis@school.com", ["Instructor", "Academics User"]),
]

TEACHER_PWD = "Teacher@123"
STUDENT_PWD = "Student@123"

ASSESSMENT_GROUP_ROOT = "All Assessment Groups"
GRADING_SCALE = "Percentage"
CRITERION = "Total Marks"

COMMENTS = [
    "Good work, keep it up!",
    "Well explained answers.",
    "Needs to show working steps.",
    "Excellent understanding of the topic.",
    "Great improvement this time.",
    "Please revise chapters 3 and 4.",
]


def exists(doctype, field, value):
    return frappe.db.exists(doctype, {field: value})


def term_name():
    """Actual doc name of the seeded Academic Term (autoname differs)."""
    return frappe.db.get_value("Academic Term", {"term_name": TERM, "academic_year": ACADEMIC_YEAR}, "name")


def room_ref(room):
    """Actual doc name of a Room (autoname is HTL-ROOM-...)."""
    return frappe.db.get_value("Room", {"room_name": room}, "name")


def get_or_create(doctype, filters, values):
    name = frappe.db.exists(doctype, filters)
    if name:
        return name
    doc = frappe.get_doc({"doctype": doctype, **values})
    doc.flags.ignore_permissions = True
    doc.insert(ignore_permissions=True)
    print(f"  + {doctype}: {doc.name}")
    return doc.name


def seed_base():
    # Gender master
    for g in ("Male", "Female", "Other"):
        if not frappe.db.exists("Gender", g):
            frappe.get_doc({"doctype": "Gender", "gender": g}).insert(ignore_permissions=True)

    get_or_create("Academic Year", {"academic_year_name": ACADEMIC_YEAR}, {
        "academic_year_name": ACADEMIC_YEAR,
        "year_start_date": "2026-04-01",
        "year_end_date": "2027-03-31",
    })
    get_or_create("Academic Term", {"term_name": TERM, "academic_year": ACADEMIC_YEAR}, {
        "term_name": TERM,
        "academic_year": ACADEMIC_YEAR,
        "term_start_date": "2026-04-01",
        "term_end_date": "2026-09-30",
    })

    # Assessment Group tree root
    if not frappe.db.exists("Assessment Group", ASSESSMENT_GROUP_ROOT):
        frappe.get_doc({
            "doctype": "Assessment Group",
            "assessment_group_name": ASSESSMENT_GROUP_ROOT,
            "parent_assessment_group": ASSESSMENT_GROUP_ROOT,
            "is_group": 1,
        }).insert(ignore_permissions=True)
        print(f"  + Assessment Group: {ASSESSMENT_GROUP_ROOT}")

    get_or_create("Grading Scale", {"grading_scale_name": GRADING_SCALE}, {
        "grading_scale_name": GRADING_SCALE,
        "intervals": [
            {"grade_code": "A+", "threshold": 90},
            {"grade_code": "A", "threshold": 80},
            {"grade_code": "B+", "threshold": 70},
            {"grade_code": "B", "threshold": 60},
            {"grade_code": "C", "threshold": 50},
            {"grade_code": "D", "threshold": 40},
            {"grade_code": "F", "threshold": 0},
        ],
    })

    get_or_create("Assessment Criteria", {"assessment_criteria": CRITERION}, {
        "assessment_criteria": CRITERION,
    })

    for r in ROOMS:
        get_or_create("Room", {"room_name": r}, {"room_name": r})

    # Holiday List — required before attendance can be marked (Company XYZ
    # has no default holiday list on a fresh install).
    hl = "Default Holiday List"
    if not frappe.db.exists("Holiday List", hl):
        frappe.get_doc({
            "doctype": "Holiday List",
            "holiday_list_name": hl,
            "from_date": "2026-01-01",
            "to_date": "2026-12-31",
            "holidays": [
                {"holiday_date": "2026-01-01", "description": "New Year"},
                {"holiday_date": "2026-08-15", "description": "Independence Day"},
                {"holiday_date": "2026-10-02", "description": "Gandhi Jayanti"},
                {"holiday_date": "2026-12-25", "description": "Christmas"},
            ],
        }).insert(ignore_permissions=True)
        print(f"  + Holiday List: {hl}")
    for company in frappe.get_all("Company", fields=["name", "default_holiday_list"]):
        if not company.default_holiday_list:
            frappe.db.set_value("Company", company.name, "default_holiday_list", hl)
            print(f"  + default holiday list set on Company {company.name}")


def seed_courses_and_programs():
    course_names = sorted({c for courses in PROGRAMS.values() for c in courses})
    for c in course_names:
        get_or_create("Course", {"course_name": c}, {"course_name": c})

    for program, courses in PROGRAMS.items():
        if not frappe.db.exists("Program", {"program_name": program}):
            frappe.get_doc({
                "doctype": "Program",
                "program_name": program,
                "program_abbreviation": "".join(w[0] for w in program.split()),
                "courses": [{"course": c} for c in courses],
            }).insert(ignore_permissions=True)
            print(f"  + Program: {program}")


def seed_users():
    created = []
    for full_name, email, roles in USERS:
        if frappe.db.exists("User", email):
            continue
        frappe.get_doc({
            "doctype": "User",
            "email": email,
            "full_name": full_name,
            "first_name": full_name,
            "user_type": "System User",
            "enabled": 1,
            "roles": [{"role": r} for r in roles],
        }).insert(ignore_permissions=True)
        print(f"  + User: {email} ({role})")
        created.append(email)
    for email in created:
        frappe.utils.password.update_password(email, TEACHER_PWD)
        print(f"  + password set: {email} / {TEACHER_PWD}")

    # Student users
    created = []
    for first, last, email, *_ in STUDENTS:
        if frappe.db.exists("User", email):
            continue
        full_name = f"{first} {last}"
        frappe.get_doc({
            "doctype": "User",
            "email": email,
            "full_name": full_name,
            "first_name": first,
            "last_name": last,
            "user_type": "System User",
            "enabled": 1,
            "roles": [{"role": "Student"}],
        }).insert(ignore_permissions=True)
        print(f"  + User: {email} (Student)")
        created.append(email)
    for email in created:
        frappe.utils.password.update_password(email, STUDENT_PWD)
        print(f"  + password set: {email} / {STUDENT_PWD}")


def seed_permissions():
    """Role/permission fixes the Flutter app needs (idempotent).

    - Teacher users get the `Academics User` role — education's full-CRUD
      academics role (plain `Instructor` can't even read Course Schedules).
    - Student gets read access on Assessment Plan (the app lists assignments
      via raw REST, and education's defaults don't grant Student read there).
    """
    for _full_name, email, roles in USERS:
        user = frappe.get_doc("User", email)
        have = {r.role for r in user.roles}
        if not set(roles).issubset(have):
            for r in roles:
                if r not in have:
                    user.append("roles", {"role": r})
            user.save(ignore_permissions=True)
            print(f"  + roles updated: {email} -> {roles}")
    if not frappe.db.exists("Custom DocPerm", {"parent": "Assessment Plan", "role": "Student"}):
        frappe.get_doc({
            "doctype": "Custom DocPerm",
            "parent": "Assessment Plan",
            "role": "Student",
            "read": 1,
        }).insert(ignore_permissions=True)
        print("  + Custom DocPerm: Student read on Assessment Plan")


def seed_instructors():
    for full_name, email, _roles in USERS:
        get_or_create("Instructor", {"instructor_name": full_name}, {
            "instructor_name": full_name,
            "status": "Active",
        })


def _make_logo_png(size=256):
    """Pure-Python PNG (no PIL): indigo→blue diagonal gradient with a white
    badge ring — a clean placeholder logo for the seeded School Profile."""
    import struct
    import zlib

    def px(x, y):
        t = (x + y) / (2.0 * size)
        r, g, b = int(30 + 45 * t), int(58 + 45 * t), int(130 + 90 * t)
        cx = cy = size / 2.0
        dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
        if dist < size * 0.42:  # outer white ring
            if dist < size * 0.36:  # inner badge fill
                r, g, b = 34, 66, 150
                # simple "book" glyph: two white bars
                if abs(y - cy) < size * 0.06 and abs(x - cx) < size * 0.22:
                    r = g = b = 255
            else:
                r = g = b = 255
        return r, g, b

    rows = b""
    for y in range(size):
        rows += b"\x00" + b"".join(bytes(px(x, y)) for x in range(size))

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(rows, 9))
    png += chunk(b"IEND", b"")
    return png


def seed_school_profile():
    """School Profile single doc: name, logo, contact info — the data the
    app shows on dashboards, settings and the admin edit screen."""
    from frappe.utils.file_manager import save_file

    try:
        profile = frappe.get_single("School Profile")
    except frappe.DoesNotExistError:
        profile = frappe.new_doc("School Profile")
        profile.flags.ignore_permissions = True
    profile.school_name = "Springfield High School"
    profile.motto = "Learn. Lead. Succeed."
    profile.contact_email = "info@springfield.edu"
    profile.contact_number = "+1 (555) 234-5678"
    profile.website = "www.springfield.edu"
    profile.address = "12 Maple Avenue, Springfield, IL 62704, USA"

    if not frappe.db.exists("File", {"file_name": "school_logo.png"}):
        fdoc = save_file(
            "school_logo.png",
            _make_logo_png(),
            dt="School Profile",
            dn=None,
            is_private=0,
        )
        profile.logo = fdoc.file_url
        print(f"  + Logo: {fdoc.file_url}")
    elif profile.logo:
        pass
    else:
        profile.logo = "/files/school_logo.png"

    profile.save(ignore_permissions=True)
    print(f"  + School Profile: {profile.school_name}")


def seed_students_and_groups():
    groups = {}
    for first, last, email, gender, dob, program, group_name in STUDENTS:
        full_name = f"{first} {last}"
        student = exists("Student", "student_email_id", email)
        if not student:
            doc = frappe.get_doc({
                "doctype": "Student",
                "first_name": first,
                "last_name": last,
                "student_email_id": email,
                "user": email,
                "gender": gender,
                "date_of_birth": dob,
                "enabled": 1,
            })
            doc.insert(ignore_permissions=True)
            student = doc.name
            print(f"  + Student: {student} ({full_name})")
        groups.setdefault(group_name, []).append((student, full_name))

    for group_name, members in groups.items():
        if exists("Student Group", "student_group_name", group_name):
            continue
        program = group_name.rsplit(" - ", 1)[0]
        doc = frappe.get_doc({
            "doctype": "Student Group",
            "academic_year": ACADEMIC_YEAR,
            "group_based_on": "Batch",
            "student_group_name": group_name,
            "program": program,
            "max_strength": 40,
            "students": [
                {"student": s, "student_name": n, "group_roll_number": i, "active": 1}
                for i, (s, n) in enumerate(members, start=1)
            ],
            "instructors": [
                {"instructor": frappe.db.get_value("Instructor", {"instructor_name": full_name}, "name")}
                for full_name, _e, _roles in USERS
                if frappe.db.exists("Instructor", {"instructor_name": full_name})
            ],
        })
        doc.insert(ignore_permissions=True)
        print(f"  + Student Group: {doc.name} ({len(members)} students)")


def seed_enrollments():
    for first, last, email, _g, _d, program, group_name in STUDENTS:
        student = exists("Student", "student_email_id", email)
        if not student:
            continue
        if frappe.db.exists("Program Enrollment", {"student": student, "program": program}):
            continue
        courses = PROGRAMS[program]
        frappe.get_doc({
            "doctype": "Program Enrollment",
            "student": student,
            "student_name": f"{first} {last}",
            "enrollment_date": "2026-04-05",
            "program": program,
            "academic_year": ACADEMIC_YEAR,
            "academic_term": term_name(),
            "courses": [{"course": c} for c in courses],
        }).insert(ignore_permissions=True)
        print(f"  + Program Enrollment: {first} {last} → {program}")


def seed_course_schedules():
    """One schedule per course per week (Mon–Fri per group) for the last
    HISTORY_WEEKS weeks PLUS the upcoming week. The attendance date is
    inherited from the schedule (set_date() in the Student Attendance
    controller), so past weeks produce a real attendance history for the
    calendar's month navigation; the upcoming week has classes the teacher
    can mark attendance for."""
    time_slots = [
        ("09:00:00", "10:00:00"),
        ("10:00:00", "11:00:00"),
        ("11:00:00", "12:00:00"),
        ("12:00:00", "13:00:00"),
        ("13:00:00", "14:00:00"),
    ]
    # History weeks use afternoon slots so they never collide with the
    # morning Assessment Plan slots for the same group/date (education
    # validates Course Schedule vs Assessment Plan overlaps).
    afternoon_slots = [
        ("14:00:00", "15:00:00"),
        ("15:00:00", "16:00:00"),
        ("16:00:00", "17:00:00"),
        ("17:00:00", "18:00:00"),
        ("18:00:00", "19:00:00"),
    ]
    groups = frappe.get_all("Student Group", filters={"academic_year": ACADEMIC_YEAR}, fields=["name", "student_group_name", "program"], order_by="name")
    instructors = frappe.get_all("Instructor", fields=["name", "instructor_name"])
    today = datetime.date.today()
    next_monday = today + datetime.timedelta(days=(7 - today.weekday()))
    # Each group's class week is staggered one week apart (matches the
    # original seed: A → next Monday, B → +1 week, C → +2 weeks). History
    # windows are 4 weeks each and fully DISJOINT across groups (A: -4..-1
    # weeks, B: -9..-6, C: -14..-11), so the 2 instructors never teach two
    # groups at the same date+time.
    count = 0
    for gi, g in enumerate(groups):
        program = g.program
        courses = [c.course for c in frappe.get_doc("Program", program).courses]
        upcoming_week = next_monday + datetime.timedelta(weeks=gi)
        # History weeks — afternoon slots so they never collide with the
        # morning Assessment Plan slots for the same group/date.
        for w in range(4 + gi * 5, gi * 5, -1):
            week_start = next_monday - datetime.timedelta(weeks=w)
            for i, course in enumerate(courses):
                instructor = instructors[i % len(instructors)].name
                room = room_ref(ROOMS[i % len(ROOMS)])
                frm, to = afternoon_slots[i % len(afternoon_slots)]
                schedule_date = week_start + datetime.timedelta(days=i)
                if frappe.db.exists("Course Schedule", {
                    "student_group": g.name, "course": course, "instructor": instructor,
                    "from_time": frm, "schedule_date": str(schedule_date),
                }):
                    continue
                frappe.get_doc({
                    "doctype": "Course Schedule",
                    "student_group": g.name,
                    "instructor": instructor,
                    "course": course,
                    "program": program,
                    "room": room,
                    "schedule_date": str(schedule_date),
                    "from_time": frm,
                    "to_time": to,
                    "class_schedule_color": ["blue", "green", "red", "orange", "teal"][i % 5],
                }).insert(ignore_permissions=True)
                count += 1
        # Upcoming week — morning slots, original pattern (existing records
        # from the first seed are skipped by the exists-check).
        for i, course in enumerate(courses):
            instructor = instructors[i % len(instructors)].name
            room = room_ref(ROOMS[i % len(ROOMS)])
            frm, to = time_slots[i % len(time_slots)]
            schedule_date = upcoming_week + datetime.timedelta(days=i)
            if frappe.db.exists("Course Schedule", {
                "student_group": g.name, "course": course, "instructor": instructor,
                "from_time": frm, "schedule_date": str(schedule_date),
            }):
                continue
            frappe.get_doc({
                "doctype": "Course Schedule",
                "student_group": g.name,
                "instructor": instructor,
                "course": course,
                "program": program,
                "room": room,
                "schedule_date": str(schedule_date),
                "from_time": frm,
                "to_time": to,
                "class_schedule_color": ["blue", "green", "red", "orange", "teal"][i % 5],
            }).insert(ignore_permissions=True)
            count += 1
    print(f"  + Course Schedules created: {count}")


def last_weekdays(n):
    out = []
    d = datetime.date.today()
    while len(out) < n:
        if d.weekday() < 5:
            out.append(d)
        d -= datetime.timedelta(days=1)
    return list(reversed(out))


def seed_attendance():
    """One attendance record per student per PAST course schedule. The
    controller overrides the date with the schedule's schedule_date, so each
    past class day (Mon–Fri per group) produces its own dated record. Future
    schedules are skipped — upcoming classes have no attendance until the
    teacher marks it (this also cleans up any future-dated records from
    earlier seeds)."""
    today = datetime.date.today()
    deleted = frappe.db.sql(
        "DELETE FROM `tabStudent Attendance` WHERE date > %s", str(today)
    )
    if deleted:
        print(f"  + Deleted {deleted} future-dated attendance records")
    groups = frappe.get_all("Student Group", filters={"academic_year": ACADEMIC_YEAR}, fields=["name"], order_by="name")
    created = 0
    for g in groups:
        group = frappe.get_doc("Student Group", g.name)
        schedules = frappe.get_all("Course Schedule", filters={"student_group": g.name}, fields=["name"], order_by="name")
        students = [(s.student, s.group_roll_number) for s in group.students if s.active]
        for sch_idx, sch in enumerate(schedules):
            sch_date = frappe.db.get_value("Course Schedule", sch.name, "schedule_date")
            if sch_date > today or is_holiday("Default Holiday List", sch_date):
                continue
            for student, roll in students:
                if frappe.db.exists("Student Attendance", {"student": student, "course_schedule": sch.name}):
                    continue
                bucket = (roll * 7 + sch_idx * 3) % 20
                status = "Present" if bucket < 17 else ("Absent" if bucket < 19 else "Leave")
                frappe.get_doc({
                    "doctype": "Student Attendance",
                    "student": student,
                    "student_name": frappe.db.get_value("Student", student, "student_name"),
                    "student_group": g.name,
                    "course_schedule": sch.name,
                    "date": str(sch_date),
                    "status": status,
                }).insert(ignore_permissions=True)
                created += 1
    print(f"  + Student Attendance records created: {created}")


def seed_assessments():
    groups = frappe.get_all("Student Group", filters={"academic_year": ACADEMIC_YEAR}, fields=["name", "program"], order_by="name")
    instructors = frappe.get_all("Instructor", fields=["name", "instructor_name"])
    plan_titles = ["Chapter Test", "Mid-Term Assessment", "Unit Test", "Weekly Quiz"]
    plans = 0
    for gi, g in enumerate(groups):
        program = frappe.get_doc("Program", g.program)
        plan_date = datetime.date.today() + datetime.timedelta(days=gi * 3 - 1)
        for i, course_link in enumerate(program.courses):
            course = course_link.course
            if frappe.db.exists("Assessment Plan", {
                "student_group": g.name, "course": course, "assessment_name": plan_titles[i % len(plan_titles)],
            }):
                continue
            instructor = instructors[i % len(instructors)]
            frm = f"{9 + i:02d}:00:00"
            to = f"{10 + i:02d}:00:00"
            plan = frappe.get_doc({
                "doctype": "Assessment Plan",
                "student_group": g.name,
                "assessment_name": plan_titles[i % len(plan_titles)],
                "assessment_group": ASSESSMENT_GROUP_ROOT,
                "grading_scale": GRADING_SCALE,
                "course": course,
                "program": g.program,
                "academic_year": ACADEMIC_YEAR,
                "academic_term": term_name(),
                "schedule_date": str(plan_date),
                "from_time": frm,
                "to_time": to,
                "examiner": instructor.name,
                "maximum_assessment_score": 100,
                "assessment_criteria": [{"assessment_criteria": CRITERION, "maximum_score": 100}],
            })
            plan.insert(ignore_permissions=True)
            plans += 1
            seed_results_for_plan(plan.name)
    print(f"  + Assessment Plans created: {plans}")


def seed_assessment_history():
    """A few past-dated Assessment Plans per group (last 3 Fridays) so the
    calendar's tap-a-day sheet has assignments on real past dates."""
    groups = frappe.get_all("Student Group", filters={"academic_year": ACADEMIC_YEAR}, fields=["name", "program"], order_by="name")
    instructors = frappe.get_all("Instructor", fields=["name", "instructor_name"])
    titles = ["Chapter Test", "Unit Test", "Weekly Quiz"]
    today = datetime.date.today()
    latest_friday = today - datetime.timedelta(days=(today.weekday() - 4) % 7)
    dates = [latest_friday - datetime.timedelta(weeks=w) for w in range(3)]
    plans = 0
    for gi, g in enumerate(groups):
        program = frappe.get_doc("Program", g.program)
        for wi, plan_date in enumerate(dates):
            course_link = program.courses[wi % len(program.courses)]
            course = course_link.course
            title = titles[wi % len(titles)]
            if frappe.db.exists("Assessment Plan", {
                "student_group": g.name, "course": course,
                "assessment_name": title, "schedule_date": str(plan_date),
            }):
                continue
            instructor = instructors[gi % len(instructors)]
            frm = f"{9 + wi:02d}:00:00"
            to = f"{10 + wi:02d}:00:00"
            plan = frappe.get_doc({
                "doctype": "Assessment Plan",
                "student_group": g.name,
                "assessment_name": title,
                "assessment_group": ASSESSMENT_GROUP_ROOT,
                "grading_scale": GRADING_SCALE,
                "course": course,
                "program": g.program,
                "academic_year": ACADEMIC_YEAR,
                "academic_term": term_name(),
                "schedule_date": str(plan_date),
                "from_time": frm,
                "to_time": to,
                "examiner": instructor.name,
                "maximum_assessment_score": 100,
                "assessment_criteria": [{"assessment_criteria": CRITERION, "maximum_score": 100}],
            })
            plan.insert(ignore_permissions=True)
            plans += 1
            seed_results_for_plan(plan.name)
    print(f"  + Historical Assessment Plans created: {plans}")


def seed_results_for_plan(plan_name):
    plan = frappe.get_doc("Assessment Plan", plan_name)
    group = frappe.get_doc("Student Group", plan.student_group)
    students = [s.student for s in group.students if s.active]
    for idx, student in enumerate(students):
        if frappe.db.exists("Assessment Result", {"assessment_plan": plan_name, "student": student}):
            continue
        # leave the last student in each group pending (ungraded)
        if idx == len(students) - 1:
            continue
        score = 55 + ((idx * 13 + len(plan_name)) % 44)  # 55..98
        grade = frappe.call("education.education.api.get_grade", grading_scale=GRADING_SCALE, percentage=score)
        frappe.get_doc({
            "doctype": "Assessment Result",
            "assessment_plan": plan_name,
            "student": student,
            "student_name": frappe.db.get_value("Student", student, "student_name"),
            "student_group": plan.student_group,
            "course": plan.course,
            "program": plan.program,
            "academic_year": plan.academic_year,
            "maximum_score": 100,
            "total_score": score,
            "grade": grade,
            "comment": COMMENTS[idx % len(COMMENTS)],
            "details": [{
                "assessment_criteria": CRITERION,
                "maximum_score": 100,
                "score": score,
                "grade": grade,
            }],
        }).insert(ignore_permissions=True)
        print(f"    + Assessment Result: {student} → {score} ({grade})")


def main():
    # frappe resolves log/asset paths from CWD on this install — chdir into
    # the bench's sites dir (the proven-reliable invocation pattern).
    os.chdir(SITES_PATH)
    os.makedirs(os.path.join(SITES_PATH, SITE, "logs"), exist_ok=True)
    frappe.init(site=SITE, sites_path=".")
    frappe.connect()
    frappe.local.flags.ignore_permissions = True
    frappe.flags.ignore_email = True

    print(f"Seeding site {SITE} ({BENCH_DIR}) ...\n")
    try:
        seed_base();              frappe.db.commit(); print("Base records done.\n")
        seed_courses_and_programs(); frappe.db.commit(); print("Programs & courses done.\n")
        seed_users();             frappe.db.commit(); print("Users done.\n")
        seed_permissions();       frappe.db.commit(); print("Permissions done.\n")
        seed_instructors();       frappe.db.commit(); print("Instructors done.\n")
        seed_school_profile();    frappe.db.commit(); print("School profile done.\n")
        seed_students_and_groups(); frappe.db.commit(); print("Students & groups done.\n")
        seed_enrollments();       frappe.db.commit(); print("Enrollments done.\n")
        seed_course_schedules();  frappe.db.commit(); print("Course schedules done.\n")
        seed_attendance();        frappe.db.commit(); print("Attendance done.\n")
        seed_assessments();       frappe.db.commit(); print("Assessments done.\n")
        seed_assessment_history(); frappe.db.commit(); print("Assessment history done.\n")
        print("=" * 60)
        print("SEED COMPLETE ✅")
        print("=" * 60)
        print("\nLogins (live):")
        print("  Administrator        / Admin@123   (System Manager)")
        for full, email, role in USERS:
            print(f"  {full:<22} {email:<30} {role}  / {TEACHER_PWD}")
        print(f"  Students ({len(STUDENTS)})           *@school.com  Student  / {STUDENT_PWD}")
        print("  e.g. alex.smith@school.com / Student@123")
    finally:
        frappe.destroy()


if __name__ == "__main__":
    sys.exit(main())
