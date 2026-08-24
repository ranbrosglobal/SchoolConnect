import frappe
from frappe.model.document import Document


class Assignment(Document):
    def validate(self):
        """Validate assignment data."""
        # Ensure instructor is linked to the course and student group
        if self.instructor and self.course and self.student_group:
            course_schedule = frappe.get_all(
                "Course Schedule",
                filters={
                    "instructor": self.instructor,
                    "course": self.course,
                    "student_group": self.student_group,
                },
                limit=1,
            )
            if not course_schedule:
                frappe.msgprint(
                    "Warning: No Course Schedule found for this instructor, course, and student group combination.",
                    indicator="orange",
                )

    def before_insert(self):
        """Set school from student group."""
        if self.student_group:
            student_group = frappe.get_doc("Student Group", self.student_group)
            if hasattr(student_group, "school"):
                self.school = student_group.school

    def on_update(self):
        """Notify students when assignment is created."""
        pass
