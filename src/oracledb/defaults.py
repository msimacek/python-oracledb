#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import os

class Defaults:
    """
    Identifies the default values used by the driver.
    """

    def __init__(self):
        self.arraysize = 100
        self.stmtcachesize = 20
        self.events = False
        self.ping_interval = 60
        self.config_dir = os.environ.get("TNS_ADMIN")
        self.fetch_lobs = True
        self.fetch_decimals = False
        self.prefetchrows = 2
        self.disable_oob = False
        self.ssl_server_dn_match = True
        self.tcp_connect_timeout = 60.0

defaults = Defaults()
