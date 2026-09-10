"""
Shared weekly-timetable definitions for School Connect.

Single source of truth for the schedule shape on the Frappe side — used by
api/admin.py (timetable endpoints) and the School Timetable Entry controller.

Period times are per-school data stored on the School doctype
(custom_timetable_periods, a JSON list of {"n": int, "time": str}); when a
school has no configuration yet, DEFAULT_PERIODS is used.
"""

import frappe

TIMETABLE_DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

DEFAULT_PERIODS = [
    {"n": 1, "time": "8:30 – 9:15"},
    {"n": 2, "time": "9:15 – 10:00"},
    {"n": 3, "time": "10:00 – 10:45"},
    {"n": 4, "time": "11:00 – 11:45"},
    {"n": 5, "time": "11:45 – 12:30"},
    {"n": 6, "time": "13:00 – 13:45"},
    {"n": 7, "time": "13:45 – 14:30"},
    {"n": 8, "time": "14:30 – 15:15"},
]

SCHOOL_PERIODS_FIELD = "custom_timetable_periods"


def normalize_periods(periods):
    """
    Validate/normalize an incoming list of {"n", "time"} for storage.

    Returns a sorted list of clean entries, or [] when nothing usable was
    given (empty list, non-dict entries, missing/invalid n or time, duplicates).
    """
    if not isinstance(periods, list):
        return []

    cleaned = []
    seen = set()
    for p in periods:
        if not isinstance(p, dict) or p.get("n") is None or not p.get("time"):
            continue
        n = frappe.utils.cint(p.get("n"))
        time = str(p.get("time")).strip()
        if n < 1 or not time or n in seen:
            continue
        seen.add(n)
        cleaned.append({"n": n, "time": time})

    cleaned.sort(key=lambda p: p["n"])
    return cleaned


def sanitize_periods(raw):
    """
    Turn a stored raw JSON value into a clean, sorted list of {"n", "time"}
    periods. Falls back to DEFAULT_PERIODS when the value is missing or
    unusable. Returns a fresh list so callers can't mutate shared state.
    """
    try:
        periods = frappe.parse_json(raw or "[]")
    except Exception:
        periods = []

    cleaned = normalize_periods(periods)
    return cleaned if cleaned else list(DEFAULT_PERIODS)


def get_school_periods(school):
    """
    The configured periods for a school, or the default schedule when the
    school has no configuration (or the field hasn't been added yet).
    Returns a fresh list so callers can't mutate shared state.
    """
    raw = ""
    if school and frappe.db.has_column("School", SCHOOL_PERIODS_FIELD):
        raw = frappe.db.get_value("School", school, SCHOOL_PERIODS_FIELD) or ""
    return sanitize_periods(raw)
