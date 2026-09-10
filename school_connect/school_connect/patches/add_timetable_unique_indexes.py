import frappe

TABLE = "`tabSchool Timetable Entry`"

# One slot per class + day + period, and no instructor double-booking.
INDEXES = [
    ("unique_class_day_period", ["student_group", "day", "period"]),
    ("unique_instructor_day_period", ["instructor", "day", "period"]),
]


def _dedupe(columns):
    """Drop duplicate rows (keeping the earliest) so the unique index can be added."""
    cols = ", ".join(columns)
    rows = frappe.db.sql(
        f"SELECT name, {cols} FROM {TABLE} ORDER BY modified asc",
        as_dict=True,
    )
    seen = set()
    to_delete = []
    for row in rows:
        key = tuple(row[c] for c in columns)
        if key in seen:
            to_delete.append(row["name"])
        else:
            seen.add(key)
    if to_delete:
        frappe.db.delete("School Timetable Entry", {"name": ["in", to_delete]})
        frappe.db.commit()
    return len(to_delete)


def execute():
    if not frappe.db.has_table("School Timetable Entry"):
        return

    existing = {
        row["Key_name"]
        for row in frappe.db.sql(f"SHOW INDEX FROM {TABLE}", as_dict=True)
    }

    # Deduping for one rule can in theory break another (only possible after a
    # race that bypassed both), so repeat passes until the rows are stable.
    for _ in range(5):
        deleted = sum(_dedupe(cols) for _, cols in INDEXES)
        if deleted == 0:
            break

    for name, columns in INDEXES:
        if name in existing:
            continue
        try:
            frappe.db.sql(
                f"ALTER TABLE {TABLE} ADD UNIQUE INDEX `{name}` ({', '.join(columns)})"
            )
        except Exception as e:
            frappe.log_error(
                f"Could not add unique index {name} on School Timetable Entry: {e}",
                "Timetable migration",
            )
