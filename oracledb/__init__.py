#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#
# Licensed under BSD license (see LICENSE.txt).
#------------------------------------------------------------------------------

__version__ = "0.0.1"

from .constants import *
from .pool import *
from .params import *

async def create_pool(params):
    """
    Create a pool with the specified parameters.
    """
    pool = Pool()
    await pool._create(params)
    return pool
