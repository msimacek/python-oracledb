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

#------------------------------------------------------------------------------
# utils.py
#
# Contains utility classes and methods.
#------------------------------------------------------------------------------

from . import errors

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


def params_initer(f):
    """
    Decorator function which is used on the ConnectParams and PoolParams
    classes. It creates the implementation object using the implementation
    class stored on the parameter class. It first, however, calls the original
    method to ensure that the keyword parameters supplied are valid (the
    original method itself does nothing).
    """
    def wrapped_f(self, *args, **kwargs):
        f(self, *args, **kwargs)
        self._impl = self._impl_class()
        if kwargs:
            self._impl.set(kwargs)
    return wrapped_f


def params_setter(f):
    """
    Decorator function which is used on the ConnectParams and PoolParams
    classes. It calls the set() method on the parameter implementation object
    with the supplied keyword arguments. It first, however, calls the original
    method to ensure that the keyword parameters supplied are valid (the
    original method itself does nothing).
    """
    def wrapped_f(self, *args, **kwargs):
        f(self, *args, **kwargs)
        self._impl.set(kwargs)
    return wrapped_f
