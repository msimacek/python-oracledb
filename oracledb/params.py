#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#
# Licensed under BSD license (see LICENSE.txt).
#------------------------------------------------------------------------------

__all__ = ["ConnectionParams", "PoolParams"]

from .constants import *

class ConnectionParams:

    def __init__(self, user_name=None, password=None, connection_class=None,
            purity=POOL_GET_PURITY_DEFAULT, tag=None, match_any_tag=False,
            sharding_key=None, super_sharding_key=None):
        self.user_name = user_name or ""
        self.password = password or ""
        self.connection_class = connection_class or ""
        self.purity = purity
        self.tag = tag or ""
        self.match_any_tag = match_any_tag
        self.sharding_key = sharding_key or []
        self.super_sharding_key = super_sharding_key or []


class PoolParams:

    def __init__(self, user_name=None, password=None, dsn=None, min_sessions=1,
            max_sessions=2, session_increment=1, threaded=False, events=False,
            get_mode=POOL_GET_MODE_WAIT, heterogeneous=False,
            external_auth=False, encoding="UTF-8", nencoding="UTF-8",
            edition=None, idle_timeout=0, wait_timeout=0,
            max_session_lifetime=0, session_callback=None):
        self.user_name = user_name or ""
        self.password = password or ""
        self.dsn = dsn or ""
        self.min_sessions = min_sessions
        self.max_sessions = max_sessions
        self.session_increment = session_increment
        self.threaded = threaded
        self.events = events
        self.get_mode = get_mode
        self.heterogeneous = heterogeneous
        self.external_auth = external_auth
        self.encoding = encoding
        self.nencoding = nencoding
        self.edition = edition
        self.idle_timeout = idle_timeout
        self.wait_timeout = wait_timeout
        self.max_session_lifetime = max_session_lifetime
        self.session_callback = session_callback

        # split dsn and password from user name if they are present and no dsn
        # and password have been specified
        if self.user_name:
            if not self.dsn:
                pos = self.user_name.find("@")
                if pos >= 0:
                    self.dsn = self.user_name[pos + 1:]
                    self.user_name = self.user_name[:pos]
            if not self.password:
                pos = self.user_name.find("/")
                if pos >= 0:
                    self.password = self.user_name[pos + 1:]
                    self.user_name = self.user_name[:pos]
