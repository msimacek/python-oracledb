#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# lob.pyx
#   Cython file defining the Lob class (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class Lob(BaseLob):
    cdef:
        dpiLob *_handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiLob_release(self._handle)

    cdef int _close(self) except -1:
        cdef int status
        with nogil:
            status = dpiLob_closeResource(self._handle)
        if status < 0:
            _raise_from_odpi()

    cdef int _file_exists(self, bint* exists) except -1:
        cdef int status
        with nogil:
            status = dpiLob_getFileExists(self._handle, exists)
        if status < 0:
            _raise_from_odpi()

    cdef int _get_chunk_size(self, uint32_t* size) except -1:
        if dpiLob_getChunkSize(self._handle, size) < 0:
            _raise_from_odpi()

    cdef object _get_file_name(self):
        cdef:
            uint32_t dir_alias_len, file_name_len
            const char *dir_alias
            const char *file_name
            int status
        with nogil:
            status = dpiLob_getDirectoryAndFileName(self._handle, &dir_alias,
                                                    &dir_alias_len,
                                                    &file_name, &file_name_len)
        if status < 0:
            _raise_from_odpi()
        return (dir_alias[:dir_alias_len].decode(),
                file_name[:file_name_len].decode())

    cdef int _get_is_open(self, bint* is_open) except -1:
        cdef int status
        with nogil:
            status = dpiLob_getIsResourceOpen(self._handle, is_open)
        if status < 0:
            _raise_from_odpi()

    cdef int _get_max_amount(self, uint64_t* max_amount) except -1:
        return self._get_size(max_amount)

    cdef int _get_size(self, uint64_t* size) except -1:
        if dpiLob_getSize(self._handle, size) < 0:
            _raise_from_odpi()

    @staticmethod
    cdef Lob _new_lob(Connection connection, DbType lob_type, dpiLob *handle):
        cdef Lob lob = Lob.__new__(Lob)
        lob.type = lob_type
        lob._connection = connection
        if dpiLob_addRef(handle) < 0:
            _raise_from_odpi()
        lob._handle = handle
        return lob

    cdef int _open(self) except -1:
        cdef int status
        with nogil:
            status = dpiLob_openResource(self._handle)
        if status < 0:
            _raise_from_odpi()

    cdef object _read(self, uint64_t offset, uint64_t amount):
        cdef:
            uint64_t buf_size
            object result
            char *buf
            int status
        if dpiLob_getBufferSize(self._handle, amount, &buf_size) < 0:
            _raise_from_odpi()
        buf = <char*> cpython.PyMem_Malloc(buf_size)
        with nogil:
            status = dpiLob_readBytes(self._handle, offset, amount, buf,
                                      &buf_size)
        try:
            if status < 0:
                _raise_from_odpi()
            result = buf[:buf_size]
            if self.type.num == DPI_ORACLE_TYPE_CLOB \
                    or self.type.num == DPI_ORACLE_TYPE_NCLOB:
                result = result.decode()
            return result
        finally:
            cpython.PyMem_Free(buf)

    cdef int _set_file_name(self, str dir_alias, str name) except -1:
        cdef:
            bytes dir_alias_bytes, name_bytes
            uint32_t dir_alias_len, name_len
            const char *dir_alias_ptr
            const char *name_ptr
            int status
        dir_alias_bytes = dir_alias.encode()
        dir_alias_ptr = dir_alias_bytes
        dir_alias_len = <uint32_t> len(dir_alias_bytes)
        name_bytes = name.encode()
        name_ptr = name_bytes
        name_len = <uint32_t> len(name_bytes)
        with nogil:
            status = dpiLob_setDirectoryAndFileName(self._handle,
                                                    dir_alias_ptr,
                                                    dir_alias_len,
                                                    name_ptr, name_len)
        if status < 0:
            _raise_from_odpi()

    cdef int _trim(self, uint64_t new_size=0) except -1:
        cdef int status
        with nogil:
            status = dpiLob_trim(self._handle, new_size)
        if status < 0:
            _raise_from_odpi()

    cdef int _write(self, object value, uint64_t offset) except -1:
        cdef:
            StringBuffer buf = StringBuffer()
            int status
        buf.set_value(value)
        with nogil:
            status = dpiLob_writeBytes(self._handle, offset, buf.ptr,
                                       buf.length)
        if status < 0:
            _raise_from_odpi()
