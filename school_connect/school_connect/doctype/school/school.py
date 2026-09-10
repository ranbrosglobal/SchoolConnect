import frappe
from frappe.model.document import Document


class School(Document):
    def validate(self):
        """Validate school data."""
        pass

    def before_insert(self):
        """Set default values before insert."""
        pass

    def on_update(self):
        """Actions after school update."""
        pass

    def on_trash(self):
        """Actions before school deletion."""
        # Check if there are any students or teachers linked
        students = frappe.get_all(
            "Student", filters={"school": self.name}, limit=1
        )
        if students:
            frappe.throw(
                "Cannot delete school with existing students. Please remove or reassign students first."
            )
