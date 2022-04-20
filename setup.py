#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

import os
from setuptools import setup, Extension

# base source directory
source_dir = os.path.join("src", "oracledb")

# determine the base implementation dependent source files (included)
impl_dir = os.path.join(source_dir, "impl", "base")
base_depends = [os.path.join(impl_dir, n) \
                for n in sorted(os.listdir(impl_dir)) if n.endswith(".pyx")]
base_pxd = os.path.join(source_dir, "base_impl.pxd")
base_depends.append(base_pxd)

# determine the thick mode dependent source files (included)
impl_dir = os.path.join(source_dir, "impl", "thick")
source_dirs = [
        os.path.join(impl_dir, "odpi", "src"),
        os.path.join(impl_dir, "odpi", "include")
]
thick_depends = [os.path.join(d, n) \
                 for d in source_dirs
                 for n in sorted(os.listdir(d)) \
                 if n.endswith(".c") or n.endswith(".h")]
thick_depends.extend(os.path.join(impl_dir, n) \
                     for n in sorted(os.listdir(impl_dir))
                     if n.endswith(".pyx") or n.endswith(".pxd"))
thick_depends.append(base_pxd)

# determine the thin mode dependent source files (included)
impl_dir = os.path.join(source_dir, "impl", "thin")
thin_depends = [os.path.join(impl_dir, n) \
                for n in sorted(os.listdir(impl_dir))
                if n.endswith(".pyx") or n.endswith(".pxi")
                        or n.endswith(".pxd") or n == "bswap.c"]
thin_depends.append(base_pxd)

setup(
    ext_modules=[
        Extension("oracledb.base_impl",
                  sources=["src/oracledb/base_impl.pyx"],
                  depends=base_depends),
        Extension("oracledb.thin_impl",
                  sources=["src/oracledb/thin_impl.pyx"],
                  depends=thin_depends),
        Extension("oracledb.thick_impl",
                  sources=["src/oracledb/thick_impl.pyx"],
                  include_dirs=["src/oracledb/impl/thick/odpi/include"],
                  depends=thick_depends)
    ]
)
