#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

class Defaults:
    """
    Identifies the default values used by the driver.
    """

    def __init__(self):
        self.thin = True
        self.arraysize = 100
        self.stmtcachesize = 20
        self.threaded = False
        self.events = False
        self.ping_interval = 60

defaults = Defaults()
