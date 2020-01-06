#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#
# Licensed under BSD license (see LICENSE.txt).
#------------------------------------------------------------------------------

class Error(Exception):
    pass


class DatabaseError(Error):
    pass


class InterfaceError(Error):
    pass
