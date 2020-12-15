#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseLob:

    def __str__(self):
        return self.read()

    cdef int _close(self) except -1:
        """
        Internal method for closing a LOB that was opened earlier.
        """
        raise NotImplementedError()

    cdef int _file_exists(self, bint* exists) except -1:
        """
        Internal method for returning whether the file referenced by a BFILE
        exists.
        """
        raise NotImplementedError()

    cdef int _get_chunk_size(self, uint32_t* size) except -1:
        """
        Internal method for returning the chunk size of the LOB.
        """
        raise NotImplementedError()

    cdef object _get_file_name(self):
        """
        Internal method for returning a 2-tuple constaining the directory alias
        and file name of a BFILE type LOB.
        """
        raise NotImplementedError()

    cdef int _get_is_open(self, bint* is_open) except -1:
        """
        Internal method for returning whether the LOB is open or not.
        """
        raise NotImplementedError()

    cdef int _get_max_amount(self, uint64_t* max_amount) except -1:
        """
        Internal method for returning the maximum amount that can be read.
        """
        raise NotImplementedError()

    cdef int _get_size(self, uint64_t* size) except -1:
        """
        Internal method for returning the size of a LOB.
        """
        raise NotImplementedError()

    cdef int _open(self) except -1:
        """
        Internal method for opening a LOB.
        """
        raise NotImplementedError()

    cdef object _read(self, uint64_t offset, uint64_t amount):
        """
        Internal method for reading a portion (or all) of the data in the LOB.
        """
        raise NotImplementedError()

    cdef int _set_file_name(self, str dir_alias, str name) except -1:
        """
        Internal method for setting the directory alias and file name
        associated with a BFILE LOB.
        """
        raise NotImplementedError()

    cdef int _trim(self, uint64_t new_size=0) except -1:
        """
        Internal method for trimming the data in the LOB to the new size
        """
        raise NotImplementedError()

    cdef int _write(self, object value, uint64_t offset) except -1:
        """
        Internal method for writing data to the LOB object.
        """
        raise NotImplementedError()

    def close(self):
        """
        Closes the LOB.
        """
        self._close()

    def fileexists(self):
        """
        Return a boolean indicating if the file referenced by the BFILE exists.
        """
        cdef bint exists
        self._file_exists(&exists)
        return exists

    def getchunksize(self):
        """
        Returns the chunk size of the LOB.
        """
        cdef uint32_t size
        self._get_chunk_size(&size)
        return size

    def getfilename(self):
        """
        Returns a 2-tuple containing the directory alias and file name of the
        LOB.
        """
        return self._get_file_name()

    def isopen(self):
        """
        Return a boolean indicating if the LOB is open.
        """
        cdef bint is_open
        self._get_is_open(&is_open)
        return is_open

    def open(self):
        """
        Open the LOB for writing.
        """
        self._open()

    def read(self, offset=1, amount=None):
        """
        Return a portion (or all) of the data in the LOB object.
        """
        cdef uint64_t actual_offset, actual_amount = 0
        actual_offset = offset
        if amount is None:
            self._get_max_amount(&actual_amount)
            if actual_amount >= actual_offset:
                actual_amount = actual_amount - actual_offset + 1
            else:
                actual_amount = 1
        else:
            actual_amount = amount
        return self._read(actual_offset, actual_amount)

    def setfilename(self, dir_alias, name):
        """
        Set the directory alias and file name associated with the BFILE LOB.
        """
        self._set_file_name(dir_alias, name)

    def size(self):
        """
        Return the size of the LOB. For BLOB and BFILE this is the number of
        bytes. For CLOB and NCLOB this is the number of UCS-2 code points.
        """
        cdef uint64_t size
        self._get_size(&size)
        return size

    def trim(self, new_size=0):
        """
        Trim the LOB to the new size.
        """
        self._trim(new_size)

    def write(self, data, offset=1):
        """
        Write the data to the LOB object at the given offset.
        """
        self._write(data, offset)
