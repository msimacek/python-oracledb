#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import os
from setuptools import setup, Extension

# determine the common driver dependent source files (included)
source_dir = os.path.join("src", "oracledb", "common")
common_depends = [os.path.join(source_dir, n) \
                  for n in sorted(os.listdir(source_dir))
                  if n.endswith(".pyx") and n != "driver.pyx"
                  or n.endswith(".pxd")]

# determine the thick driver dependent source files (included)
base_dir = os.path.join("src", "oracledb", "thick")
source_dirs = [
        os.path.join(base_dir, "odpi", "src"),
        os.path.join(base_dir, "odpi", "include")
]
thick_depends = [os.path.join(d, n) \
                 for d in source_dirs
                 for n in sorted(os.listdir(d)) \
                 if n.endswith(".c") or n.endswith(".h")]
thick_depends.extend(os.path.join(base_dir, n) \
                     for n in sorted(os.listdir(base_dir))
                     if n.endswith(".pyx") and n != "driver.pyx"
                     or n.endswith(".pxd"))

# determine the thin driver dependent source files (included)
source_dir = os.path.join("src", "oracledb", "thin")
thin_depends = [os.path.join(source_dir, n) \
                for n in sorted(os.listdir(source_dir))
                if n.endswith(".pyx") and n != "driver.pyx"
                or n.endswith(".pxi") or n.endswith(".pxd") or n == "hton.c"]

setup(
    ext_modules=[
        Extension("oracledb.common.driver",
                  sources=["src/oracledb/common/driver.pyx"],
                  depends=common_depends),
        Extension("oracledb.thin.driver",
                  sources=["src/oracledb/thin/driver.pyx"],
                  depends=thin_depends),
        Extension("oracledb.thick.driver",
                  sources=["src/oracledb/thick/driver.pyx"],
                  include_dirs=["src/oracledb/thick/odpi/include"],
                  depends=thick_depends)
    ]
)
