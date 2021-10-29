#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import errors

# the driver only supports creating connections/pools with either the thin
# implementation or the thick implementation, not both simultaneously; this
# flag is used to indicate which mode is currently being used:
# None: neither thick nor thin implementation has been used yet
# False: thick implementation is being used
# True: thin implementation is being used
thin_mode = None

def check_and_return_mode(requested_thin_mode=None):
    """
    Returns the current state of the driver. If neither the thick nor the thin
    implementation have been used yet (thin_mode=None), the mode is set to the
    requested mode (or thin, if no mode is requested) and returned; otherwise,
    if the mode requested is specified and does not match the current mode, an
    error is raised.

    NOTE: the current implementation of the driver only requires the requested
    thin mode to be set when initializing the thick driver; for this reason the
    error raised is specified about a thin connection already being created. If
    this assumption changes, a new error message will be required.
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
