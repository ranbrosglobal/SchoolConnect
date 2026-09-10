# Copyright (c) 2026, School Connect and contributors
# For license information, please see license.txt

import frappe
from frappe.model.document import Document


class StudentSubmission(Document):
    def validate(self):
        if self.student_name and not self.student:
            self.student_name = frappe.db.get_value("Student", self.student, "student_name")
        if self.assessment_plan and not self.student_group:
            self.student_group = frappe.db.get_value(
                "Assessment Plan", self.assessment_plan, "student_group"
            )
        if self.assessment_plan and not self.course:
            self.course = frappe.db.get_value("Assessment Plan", self.assessment_plan, "course")
        if self.course and not self.course_name:
            self.course_name = frappe.db.get_value("Course", self.course, "course_name")
