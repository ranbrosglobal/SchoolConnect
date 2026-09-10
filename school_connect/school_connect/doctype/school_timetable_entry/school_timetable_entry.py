"""
School Timetable Entry — controller.

Enforces the weekly-schedule invariants on every write path (API, Frappe UI,
scripts), not just the admin API:

  - day must be one of the weekdays in the timetable
  - period must be within the school's configured period count
  - only one slot per class + day + period (saving over an entry is an update)
  - an instructor can only teach one class per day + period

Composite unique indexes on (student_group, day, period) and
(instructor, day, period) back these rules at the database level; this
validate provides friendly messages before the database is ever hit.
"""

import frappe
from frappe import _
from frappe.model.document import Document

from school_connect.timetable import TIMETABLE_DAYS, get_school_periods


class SchoolTimetableEntry(Document):
    def validate(self):
        self._validate_day_and_period()
        self._validate_no_class_duplicate()
        self._validate_no_instructor_clash()

    def _validate_day_and_period(self):
        if self.day not in TIMETABLE_DAYS:
            frappe.throw(_("Day must be one of {0}").format(", ".join(TIMETABLE_DAYS)))

        period = frappe.utils.cint(self.period)
        period_count = len(get_school_periods(self.school))
        if period < 1 or period > period_count:
            frappe.throw(
                _("Period must be between 1 and {0}").format(period_count)
            )

    def _validate_no_class_duplicate(self):
        if not (self.student_group and self.day and self.period):
            return

        existing = frappe.db.get_value(
            "School Timetable Entry",
            {
                "student_group": self.student_group,
                "day": self.day,
                "period": self.period,
                "name": ["!=", self.name],
            },
            "name",
        )
        if existing:
            frappe.throw(
                _("This class already has a slot on {0} period {1} — edit that slot instead").format(
                    self.day, self.period
                )
            )

    def _validate_no_instructor_clash(self):
        if not (self.instructor and self.day and self.period):
            return

        clash = frappe.db.get_value(
            "School Timetable Entry",
            {
                "instructor": self.instructor,
                "day": self.day,
                "period": self.period,
                "student_group": ["!=", self.student_group],
                "name": ["!=", self.name],
            },
            ["instructor", "student_group"],
            as_dict=True,
        )
        if clash:
            teacher = (
                frappe.db.get_value("Instructor", clash.instructor, "instructor_name")
                or clash.instructor
            )
            other = (
                frappe.db.get_value(
                    "Student Group", clash.student_group, "student_group_name"
                )
                or clash.student_group
            )
            frappe.throw(
                _("{0} already teaches {1} on {2} period {3}").format(
                    teacher, other, self.day, self.period
                )
            )
