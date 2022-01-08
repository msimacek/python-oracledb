#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from typing import Callable, Union, Type
from . import errors
from .dbobject import DbObjectType
from .base_impl import DbType

class Var:

    def __repr__(self):
        if self._impl.is_array:
            value = self._impl.values[:self._impl.num_elements_in_array]
        elif self._impl.num_elements == 1:
            value = self._impl.values[0]
        else:
            value = self._impl.values
        typ = self._type
        return f"<oracledb.Var of type {typ.name} with value {repr(value)}>"

    @classmethod
    def _from_impl(cls, impl):
        var = cls.__new__(cls)
        var._impl = impl
        var._type = impl.objtype if impl.objtype is not None else impl.dbtype
        return var

    @property
    def actual_elements(self) -> int:
        """
        This read-only attribute returns the actual number of elements in the
        variable. This corresponds to the number of elements in a PL/SQL
        index-by table for variables that are created using the method
        Cursor.arrayvar(). For all other variables this value will be identical
        to the attribute num_elements.
        """
        if self._impl.is_array:
            return self._impl.num_elements_in_array
        return self._impl.num_elements

    @property
    def actualElements(self) -> int:
        """
        Deprecated. Use property actual_elements instead.
        """
        return self.actual_elements

    @property
    def buffer_size(self) -> int:
        """
        This read-only attribute returns the size of the buffer allocated for
        each element in bytes.
        """
        return self._impl.buffer_size

    @property
    def bufferSize(self) -> int:
        """
        Deprecated. Use property buffer_size intead().
        """
        return self.buffer_size

    def getvalue(self, pos: int=0) -> object:
        """
        Return the value at the given position in the variable. For variables
        created using the method Cursor.arrayvar() the value returned will be a
        list of each of the values in the PL/SQL index-by table. For variables
        bound to DML returning statements, the value returned will also be a
        list corresponding to the returned data for the given execution of the
        statement (as identified by the pos parameter).
        """
        if self._impl.is_array:
            return self._impl.values[:self._impl.num_elements_in_array]
        if pos >= self._impl.num_elements:
            raise IndexError("position out of range")
        return self._impl.values[pos]

    @property
    def inconverter(self) -> Callable:
        """
        This read-only attribute specifies the method used to convert data from
        Python to the Oracle database. The method signature is converter(value)
        and the expected return value is the value to bind to the database. If
        this attribute is None, the value is bound directly without any
        conversion.
        """
        return self._impl.inconverter

    @property
    def num_elements(self) -> int:
        """
        This read-only attribute returns the number of elements allocated in an
        array, or the number of scalar items that can be fetched into the
        variable or bound to the variable.
        """
        return self._impl.num_elements

    @property
    def numElements(self) -> int:
        """
        Deprecated. Use property num_elements instead.
        """
        return self.num_elements

    @property
    def outconverter(self) -> Callable:
        """
        This read-only attribute specifies the method used to convert data from
        the Oracle database to Python. The method signature is converter(value)
        and the expected return value is the value to return to Python. If this
        attribute is None, the value is returned directly without any
        conversion.
        """
        return self._impl.outconverter

    def setvalue(self, pos: int, value: object) -> None:
        """
        Set the value at the given position in the variable.
        """
        self._impl.set_value(pos, value)

    @property
    def size(self) -> int:
        """
        This read-only attribute returns the size of the variable. For strings
        this value is the size in characters. For all others, this is same
        value as the attribute buffer_size.
        """
        return self._impl.size

    @property
    def type(self) -> Union[DbType, DbObjectType]:
        """
        This read-only attribute returns the type of the variable. This will be
        an Oracle Object Type if the variable binds Oracle objects; otherwise,
        it will be one of the database type constants.
        """
        return self._type

    @property
    def values(self) -> list:
        """
        This read-only attribute returns a copy of the value of all actual
        positions in the variable as a list. This is the equivalent of calling
        getvalue() for each valid position and the length will correspond to
        the value of the actual_elements attribute.
        """
        if self._impl.is_array:
            return self._impl.values[:self._impl.num_elements_in_array]
        return self._impl.values
