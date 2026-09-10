import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_fields


def execute():
    """
    Add a 'Subjects' field on the Instructor doctype (comma-separated list of
    subjects the teacher can teach). The timetable stores the subject per slot,
    so this field only drives the subject picker — changing it never rewrites
    past timetable entries.
    """
    if not frappe.db.has_table("Instructor"):
        return

    create_custom_fields(
        {
            "Instructor": [
                {
                    "fieldname": "custom_subjects",
                    "label": "Subjects",
                    "fieldtype": "Small Text",
                    "description": "Comma-separated subjects this teacher can teach (e.g. Mathematics, Physics).",
                }
            ]
        },
        ignore_validate=True,
        ignore_user_permissions=True,
    )
