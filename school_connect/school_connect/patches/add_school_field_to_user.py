import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_fields


def execute():
    """
    Add a 'School' link field on the User doctype.
    School Admins are linked to their school through this field, which is
    used to scope admin dashboard data to a single school.
    """
    if not frappe.db.has_table("User"):
        return

    create_custom_fields(
        {
            "User": [
                {
                    "fieldname": "custom_school",
                    "label": "School",
                    "fieldtype": "Link",
                    "options": "School",
                    "in_standard_filter": 1,
                    "in_list_view": 0,
                    "description": "School this user manages (for School Admin role).",
                }
            ]
        },
        ignore_validate=True,
        ignore_user_permissions=True,
    )
