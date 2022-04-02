#------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

cdef int _set_bool_param(dict args, str name, bint *out_val) except -1:
    """
    Sets a boolean parameter to the value provided in the dictionary. This can
    be a case-insenstive string matching on/off, yes/no or true/false (such as
    when parsed from a connect string). It can also be a directly passed
    argument which will be explicitly converted to a boolean value.
    """
    in_val = args.get(name)
    if in_val is not None:
        if isinstance(in_val, str):
            out_val[0] = (in_val.strip().lower() in ("on", "yes", "true"))
        else:
            out_val[0] = bool(in_val)


cdef int _set_duration_param(dict args, str name, double *out_val) except -1:
    """
    Sets a duration parameter to the value provided in the dictionary. This can
    be a string (such as when parsed from a connect string) containing a
    floating point value followed by an otional unit: ms (milliseconds), sec
    (seconds) or min (minutes). It can also be a directly passed argument which
    will be explicitly converted to a floating point value.
    """
    in_val = args.get(name)
    if in_val is not None:
        if isinstance(in_val, str):
            in_val = in_val.strip().lower()
            if in_val.endswith("sec"):
                out_val[0] = float(in_val[:-3].strip())
            elif in_val.endswith("ms"):
                out_val[0] = float(in_val[:-2].strip()) / 1000
            elif in_val.endswith("min"):
                out_val[0] = float(in_val[:-3].strip()) * 60
            else:
                out_val[0] = float(in_val.strip())
        else:
            out_val[0] = float(in_val)


cdef int _set_int_param(dict args, str name, int* out_val) except -1:
    """
    Sets an integer parameter to the value provided in the dictionary. This
    can be a string (such as when parsed from a connect string). It can also be
    a directly passed argument which will be explicitly converted to an integer
    value.
    """
    in_val = args.get(name)
    if in_val is not None:
        out_val[0] = int(in_val)


cdef int _set_uint_param(dict args, str name, uint32_t* out_val) except -1:
    """
    Sets an unsigned integer parameter to the value provided in the dictionary.
    This can be a string (such as when parsed from a connect string). It can
    also be a directly passed argument which will be explicitly converted to an
    integer value.
    """
    in_val = args.get(name)
    if in_val is not None:
        out_val[0] = int(in_val)


cdef int _set_uint_param_with_deprecated_name(dict args, str name,
                                              str deprecated_name,
                                              uint32_t* out_val) except -1:
    """
    Similar to _set_uint_param() but also checks to see if the deprecated
    parameter name has been used.
    """
    in_val = args.get(name)
    deprecated_val = args.get(deprecated_name)
    if in_val is not None and deprecated_val is not None:
        errors._raise_err(errors.ERR_DUPLICATED_PARAMETER,
                          deprecated_name=deprecated_name, new_name=name)
    elif in_val is not None:
        out_val[0] = int(in_val)
    elif deprecated_val is not None:
        out_val[0] = int(deprecated_val)

cdef int _set_obj_param_with_deprecated_name(dict args, str name,
                                             str deprecated_name,
                                             object target) except -1:
    """
    Sets an object parameter to the value provided in the dictionary. If a
    value is specified it is set directly on the target.
    """
    in_val = args.get(name)
    deprecated_val = args.get(deprecated_name)
    if in_val is not None and deprecated_val is not None:
        errors._raise_err(errors.ERR_DUPLICATED_PARAMETER,
                          deprecated_name=deprecated_name, new_name=name)
    elif in_val is not None:
        setattr(target, name, in_val)
    elif deprecated_val is not None:
        setattr(target, name, deprecated_val)


cdef int _set_protocol_param(dict args, str name, object target) except -1:
    """
    Sets a protocol parameter to the value provided in the dictionary. This
    must be one of "tcp" or "tcps" currently. If it is not one of these values
    an error is raised. If a value is specified and meets the criteria it is
    set directly on the target (since strings are treated as Python objects).
    """
    in_val = args.get(name)
    if in_val is not None:
        in_val = in_val.lower()
        if in_val not in ("tcp", "tcps"):
            errors._raise_err(errors.ERR_INVALID_PROTOCOL, protocol=in_val)
        setattr(target, name, in_val)


cdef int _set_purity_param(dict args, str name, uint32_t* out_val) except -1:
    """
    Sets a purity parameter to the value provided in the dictionary. This
    must be one of "new" or "self" currently (or the equivalent constants, if
    specified directly). If it is not one of these values an error is raised.
    """
    in_val = args.get(name)
    if in_val is not None:
        if isinstance(in_val, str):
            in_val = in_val.lower()
            if in_val == "new":
                out_val[0] = constants.PURITY_NEW
            elif in_val == "self":
                out_val[0] = constants.PURITY_ANY
            else:
                errors._raise_err(errors.ERR_INVALID_POOL_PURITY,
                                  purity=in_val)
        else:
            if in_val not in (constants.PURITY_ANY, constants.PURITY_NEW,
                              constants.PURITY_DEFAULT):
                errors._raise_err(errors.ERR_INVALID_POOL_PURITY,
                                  purity=in_val)
            out_val[0] = in_val


cdef int _set_server_type_param(dict args, str name, object target) except -1:
    """
    Sets a server type parameter to the value provided in the dictionary. This
    must be one of "dedicated", "pooled" or "shared" currently. If it is not
    one of these values an error is raised. If a value is specified and meets
    the criteria it is set directly on the target (since strings are treated as
    Python objects).
    """
    in_val = args.get(name)
    if in_val is not None:
        in_val = in_val.lower()
        if in_val not in ("dedicated", "pooled", "shared"):
            errors._raise_err(errors.ERR_INVALID_SERVER_TYPE,
                              server_type=in_val)
        setattr(target, name, in_val)


cdef int _set_str_param(dict args, str name, object target) except -1:
    """
    Sets a string parameter to the value provided in the dictionary. If a value
    is specified it is set directly on the target (since strings are treated as
    Python objects).
    """
    in_val = args.get(name)
    if in_val is not None:
        setattr(target, name, str(in_val))
