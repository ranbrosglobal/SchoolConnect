# Copyright (c) 2026, School Connect and contributors
# For license information, please see license.txt

from __future__ import annotations

import frappe
from frappe.model.document import Document


class School(Document):
    """Registry entry for one school on the super-admin site. Each school runs
    on its own Frappe site (own database); this doc holds its public profile
    plus the school-admin credentials the super admin manages."""

    def validate(self):
        if not self.school_name:
            frappe.throw("School Name is required.")
        if not self.site:
            frappe.throw("Site / Subdomain is required.")
