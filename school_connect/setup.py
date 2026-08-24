from setuptools import setup, find_packages

with open("requirements.txt") as f:
    install_requires = f.read().strip().split("\n")

setup(
    name="school_connect",
    version="0.0.1",
    description="School Attendance & Management System for ERPNext",
    author="School Connect",
    author_email="admin@schoolconnect.com",
    packages=find_packages(),
    zip_safe=False,
    include_package_data=True,
    install_requires=install_requires,
)
