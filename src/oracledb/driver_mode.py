#------------------------------------------------------------------------------
# Copyright (c) 2021, 2022 Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import errors

# The driver only supports creating connections and pools with either the thin
# implementation or the thick implementation, not both simultaneously; this
# flag is used to indicate which mode is currently being used:
#
# None: neither thick nor thin implementation has been used yet
# False: thick implementation is being used
# True: thin implementation is being used
thin_mode = None

def check_and_return_mode(requested_thin_mode=None):
    """
    Internal function to return the current mode of python-oracledb.

    If neither the thick nor the thin implementation have been used yet (the
    value of thin_mode is None), then:

      - the mode is set to the requested mode, or

      - the mode is set to thin, if no mode is requested.

    Otherwise, if requested_thin_mode is used and the mode requested
    does not match the current mode, an error is raised.

    NOTE: the current implementation of the driver only requires
    requested_thin_mode to be set when initializing the thick driver; for this
    reason the error raised is specified about a thin connection already being
    created. If this assumption changes, a new error message will be required.
    """
    global thin_mode
    if thin_mode is None:
        if requested_thin_mode is None:
            thin_mode = True
        else:
            thin_mode = requested_thin_mode
    elif requested_thin_mode is not None and requested_thin_mode != thin_mode:
        errors._raise_err(errors.ERR_THIN_CONNECTION_ALREADY_CREATED)
    return thin_mode
