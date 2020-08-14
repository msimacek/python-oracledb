#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import os
from setuptools import setup, Extension

source_dir = os.path.join("src", "oracledb", "thick", "odpi", "src")
thick_depends = [os.path.join(source_dir, n) \
                 for n in sorted(os.listdir(source_dir)) \
                 if n.endswith(".c") or n.endswith(".h")]
thick_depends.append(os.path.join("src", "oracledb", "thick", "odpi.pxd"))

source_dir = os.path.join("src", "oracledb", "thin")
thin_depends = [os.path.join(source_dir, n) \
                for n in ["hton.c", "hton.pxd", "protocol.pxd"]]

setup(
    ext_modules=[
        Extension("oracledb.common.driver",
                  sources=["src/oracledb/common/driver.pyx"]),
        Extension("oracledb.thin.driver",
                  sources=["src/oracledb/thin/driver.pyx"],
                  depends=thin_depends),
        Extension("oracledb.thick.driver",
                  sources=["src/oracledb/thick/driver.pyx"],
                  include_dirs=["src/oracledb/thick/odpi/include"],
                  depends=thick_depends)
    ]
)
