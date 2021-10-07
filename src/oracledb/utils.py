#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import errors
from .connect_params import ConnectParams

class CheckImpls:
    """
    Decorator class which is used on the base implementation method and checks
    to see which implementation is currently being used (and therefore has no
    support for the method). An exception is raised letting the user know which
    implementation does support the method. Currently there are only two
    implementations (thick and thin) so the assumption is made that the
    implementation not currently running does support the method.
    """

    def __init__(self, feature):
        self.feature = feature

    def __call__(self, f):
        feature = self.feature
        def wrapped_f(self, *args, **kwargs):
            class_name = type(self).__name__
            driver_type = "thin" if class_name.startswith("Thick") else "thick"
            errors._raise_err(errors.ERR_FEATURE_NOT_SUPPORTED,
                              feature=feature, driver_type=driver_type)
        return wrapped_f

def process_connect_params(dsn, user, password, params, additional_args):
    """
    Process the connection parameters and return the massaged parameters as a
    4-tuple (dsn, user, password, params).
    """
    if params is None:
        params = ConnectParams(**additional_args)
    elif not isinstance(params, ConnectParams):
        message = "params must be of type oracledb.ConnectParams"
        raise TypeError(message)
    elif additional_args:
        params._set_by_keyword_args(additional_args)
    if dsn is not None:
        split_user, split_password, dsn = params.parse_dsn(dsn)
        if user and split_user or password and split_password:
            message = "credentials cannot be specified as independent " \
                      "parameters and as part of the dsn parmeters"
            raise TypeError(message)
        if split_user:
            user = split_user
        if split_password:
            password = split_password
    return (dsn, user, password, params)
