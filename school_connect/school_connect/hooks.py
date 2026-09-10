app_name = "school_connect"
app_title = "School Connect"
app_publisher = "School Connect"
app_description = "School Attendance & Management System"
app_email = "admin@schoolconnect.com"
app_license = "MIT"

# Includes
includes = [
    "school_connect/public/js",
    "school_connect/public/css",
]

# Doc Events
doc_events = {
    "User": {
        "after_insert": "school_connect.events.user_events.after_insert",
    },
}

# Permission Methods
has_permission = {
    "Student Attendance": "school_connect.api.permissions.student_attendance_permission",
    "Assignment": "school_connect.api.permissions.assignment_permission",
    "Assignment Submission": "school_connect.api.permissions.assignment_submission_permission",
}

# Website route rules
website_route_rules = []

# Scheduler Events
scheduler_events = {
    "daily": [
        "school_connect.tasks.daily",
    ],
}

# Fixtures (for custom fields, etc.)
fixtures = [
    {
        "dt": "Custom Field",
        "filters": [
            ["module", "=", "School Connect"],
        ],
    },
    {
        "dt": "Property Setter",
        "filters": [
            ["module", "=", "School Connect"],
        ],
    },
    {
        "dt": "Role",
        "filters": [
            ["role_name", "in", ["School Admin", "Instructor", "Student"]],
        ],
    },
]
