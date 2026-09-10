# Copyright (c) 2026, School Connect and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document


class SchoolProfile(Document):
    """Single doctype holding the school's public profile: name, logo and
    contact details, shown in the mobile app dashboards and settings."""

    def validate(self):
        if not self.school_name:
            frappe.throw("School Name is required.")
