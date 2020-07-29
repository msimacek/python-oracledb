#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import pathlib
import sys

if sys.version_info < (3, 6):
    raise RuntimeError("Python 3.6 or higher is required.")

from setuptools import setup, Extension
from Cython.Build import cythonize

MODULE_NAME = "oracledb"
BASE_DIR = pathlib.Path(__file__).parent

with open(BASE_DIR / MODULE_NAME / "__init__.py") as f:
    for line in f:
        if line.startswith("__version__"):
            MODULE_VERSION = line.strip().split()[-1]
            break
    else:
        raise RuntimeError("unable to determine version of module!")

setup(
    name=MODULE_NAME,
    version=MODULE_VERSION,
    description="Python interface to Oracle",
    classifiers=[
        "Development Status :: 1 - Planning",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: BSD License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3 :: Only",
        "Programming Language :: Python :: Implementation :: CPython",
        "Topic :: Database :: Front-Ends"
    ],
    python_requires='>=3.6.0',
    zip_safe=False,
    author = "Anthony Tuininga",
    author_email = "anthony.tuininga@oracle.com",
    setup_requires="Cython",
    ext_modules=cythonize([
        Extension(
            "oracledb.common.driver",
            ["oracledb/common/driver.pyx"]
        ),
        Extension(
            "oracledb.thin.driver",
            ["oracledb/thin/driver.pyx"]
        ),
        Extension(
            "oracledb.thick.driver",
            ["oracledb/thick/driver.pyx"],
            include_dirs=["oracledb/thick/odpi/include"]
        )]
    )
)
