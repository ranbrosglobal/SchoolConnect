import frappe
from frappe import _
from frappe.model.document import Document
from frappe.utils import getdate


class AssignmentSubmission(Document):
    def validate(self):
        """Validate submission data."""
        # Check if student is enrolled in the assignment's course
        if self.assignment and self.student:
            assignment = frappe.get_doc("Assignment", self.assignment)
            student = frappe.get_doc("Student", self.student)

            # Verify student is in the correct student group
            if assignment.student_group:
                student_in_group = frappe.get_all(
                    "Student Group Student",
                    filters={
                        "parent": assignment.student_group,
                        "student": self.student,
                    },
                    limit=1,
                )
                if not student_in_group:
                    frappe.throw(
                        "Student is not enrolled in the assignment's student group."
                    )

    def before_insert(self):
        """Set default values."""
        self.submitted_at = frappe.utils.now_datetime()
        self.status = "Submitted"

        # Extract file name from URL
        if self.file:
            self.file_name = self.file.split("/")[-1]

        # Enforce the assignment's due-date deadline for new submissions.
        # Admins may still record late submissions manually.
        if self.assignment:
            roles = frappe.get_roles(frappe.session.user)
            is_admin = any(
                r in ("System Manager", "School Admin", "Administrator")
                for r in roles
            )
            if not is_admin:
                assignment = frappe.get_doc("Assignment", self.assignment)
                if (
                    assignment.due_date
                    and getdate(self.submitted_at) > assignment.due_date
                ):
                    frappe.throw(
                        _(
                            "The submission deadline for this assignment has passed "
                            "(was due on {0})."
                        ).format(assignment.due_date)
                    )

    def on_update(self):
        """Update assignment submission count."""
        pass
