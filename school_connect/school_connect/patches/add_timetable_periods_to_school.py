import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_fields

from school_connect.timetable import SCHOOL_PERIODS_FIELD


def execute():
    """
    Add a 'Timetable Periods' JSON field on the School doctype.

    Stores this school's weekly periods as a list of {"n": int, "time": str}
    (e.g. [{"n": 1, "time": "8:30 - 9:15"}, ...]). Schools without a value
    fall back to the default schedule in school_connect.timetable.
    """
    if not frappe.db.has_table("School"):
        return

    create_custom_fields(
        {
            "School": [
                {
                    "fieldname": SCHOOL_PERIODS_FIELD,
                    "label": "Timetable Periods",
                    "fieldtype": "JSON",
                    "description": 'JSON list of {"n": 1, "time": "8:30 - 9:15"} entries defining this school\'s timetable periods.',
                    "default": "[]",
                }
            ]
        },
        ignore_validate=True,
        ignore_user_permissions=True,
    )
