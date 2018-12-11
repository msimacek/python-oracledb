"""
Distutils script for oracledb.
"""

import distutils.core
import os
import sys

# if setuptools is detected, use it to add support for eggs
try:
    from setuptools import setup, Extension
except:
    from distutils.core import setup
    from distutils.extension import Extension

# define build constants
BUILD_VERSION = "0.0.1-dev"

# setup extra link and compile args
extraLinkArgs = []
extraCompileArgs = []
if sys.platform == "aix4":
    extraCompileArgs.append("-qcpluscmt")
elif sys.platform == "aix5":
    extraCompileArgs.append("-DAIX5")
elif sys.platform == "cygwin":
    extraLinkArgs.append("-Wl,--enable-runtime-pseudo-reloc")
elif sys.platform == "darwin":
    extraLinkArgs.append("-shared-libgcc")

class test(distutils.core.Command):
    description = "run the test suite for the extension"
    user_options = []

    def finalize_options(self):
        pass

    def initialize_options(self):
        pass

    def run(self):
        self.run_command("build")
        buildCommand = self.distribution.get_command_obj("build")
        sys.path.insert(0, os.path.abspath("test"))
        sys.path.insert(0, os.path.abspath(buildCommand.build_lib))
        fileName = os.path.join("test", "test.py")
        exec(open(fileName).read())

# define classifiers for the package index
classifiers = [
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: BSD License",
        "Natural Language :: English",
        "Operating System :: OS Independent",
        "Programming Language :: C",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3",
        "Topic :: Database"
]

# define sources
sourceDir = "src"
sources = [os.path.join(sourceDir, n) \
        for n in sorted(os.listdir(sourceDir)) if n.endswith(".c")]
depends = ["src/pyoModule.h"]


# define ODPI-C sources, libraries and include directories; if the environment
# variables ODPIC_INC_DIR and ODPIC_LIB_DIR are both set, assume these
# locations contain a compiled installation of ODPI-C; otherwise, use the
# source of ODPI-C found in the odpi subdirectory
dpiIncludeDir = os.environ.get("ODPIC_INC_DIR")
dpiLibDir = os.environ.get("ODPIC_LIB_DIR")
if dpiIncludeDir and dpiLibDir:
    dpiSources = []
    includeDirs = [dpiIncludeDir]
    libraries = ["odpic"]
    libraryDirs = [dpiLibDir]
else:
    includeDirs = ["odpi/include", "odpi/src"]
    dpiSourceDir = os.path.join("odpi", "src")
    dpiSources = [os.path.join(dpiSourceDir, n) \
            for n in sorted(os.listdir(dpiSourceDir)) if n.endswith(".c")]
    depends.extend(["odpi/include/dpi.h", "odpi/src/dpiImpl.h",
            "odpi/src/dpiErrorMessages.h"])
    libraries = []
    libraryDirs = []

# setup the extension
extension = Extension(
        name = "_oracledb",
        include_dirs = includeDirs,
        extra_compile_args = extraCompileArgs,
        define_macros = [("PYO_BUILD_VERSION", BUILD_VERSION)],
        extra_link_args = extraLinkArgs,
        sources = sources + dpiSources,
        depends = depends,
        libraries = libraries,
        library_dirs = libraryDirs)

# perform the setup
setup(
        name = "oracledb",
        version = BUILD_VERSION,
        description = "Python interface to Oracle",
        cmdclass = dict(test = test),
        data_files = [ ("oracledb-doc", ["LICENSE.txt", "README.txt"]) ],
        long_description = \
            "Asynchronous API for accessing Oracle Database",
        author = "Anthony Tuininga",
        author_email = "anthony.tuininga@gmail.com",
        url = "https://oracle.github.io/py-oracledb",
        packages = ["oracledb"],
        ext_modules = [extension],
        keywords = "Oracle",
        license = "BSD License",
        classifiers = classifiers)

