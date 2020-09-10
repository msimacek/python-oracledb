#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import decimal

from libc.string cimport memcpy

ctypedef unsigned char char_type

include "hton.pxd"

DEF BUFFER_CHUNK_SIZE = 2048

@cython.final
cdef class ReadBuffer:

    cdef:
        const char_type *_data
        ssize_t _size
        ssize_t _offset
        int _view_count

    def __cinit__(self, const char_type[:] data):
        self._data = &data[0]
        self._size = data.shape[0]
        self._offset = 0

    def __getbuffer__(self, Py_buffer *buf, int flags):
        self._view_count += 1
        cpython.PyBuffer_FillInfo(buf, self, <char*> self._data, self._size, 1,
                flags)

    def __releasebuffer__(self, Py_buffer *buf):
        self._view_count -= 1

    cdef inline const char_type* _get_raw(self, ssize_t num_bytes) except NULL:
        cdef const char_type *ptr = &self._data[self._offset]
        if self._offset + num_bytes > self._size:
            raise BufferError('Not enough data in buffer!')
        self._offset += num_bytes
        return ptr

    cdef ssize_t bytes_left(self):
        return self._size - self._offset

    cdef void skip_bytes(self, ssize_t num_bytes):
        self._get_raw(num_bytes)

    cdef void unread_bytes(self, ssize_t num_bytes):
        self._offset -= num_bytes
        if self._offset < 0:
            self._offset = 0

    cdef uint8_t read_uint8(self) except *:
        cdef const char_type *ptr = self._get_raw(1)
        return ptr[0]

    cdef int8_t read_int8(self) except *:
        return <int8_t> self.read_uint8()

    cdef uint16_t read_uint16(self) except *:
        cdef const char_type *ptr = self._get_raw(2)
        return unpack_uint16(ptr)

    cdef uint16_t read_native_uint16(self) except *:
        cdef const uint16_t *ptr = <uint16_t*> self._get_raw(2)
        return ptr[0]

    cdef int16_t read_int16(self) except *:
        return <int16_t> self.read_uint16()

    cdef uint32_t read_uint32(self) except *:
        cdef const char_type *ptr = self._get_raw(4)
        return unpack_uint32(ptr)

    cdef uint32_t read_native_uint32(self) except *:
        cdef const uint32_t *ptr = <uint32_t*> self._get_raw(4)
        return ptr[0]

    cdef int32_t read_int32(self) except *:
        return <int32_t> self.read_uint32()

    cdef bytes read_bytes(self, ssize_t num_bytes):
        cdef const char_type *ptr = self._get_raw(num_bytes)
        return cpython.PyBytes_FromStringAndSize(<char*> ptr, num_bytes)

    cdef bytes read_bytes_chunked(self, uint8_t num_bytes, char_type* buf,
            uint32_t max_length_bytes):
        cdef total_num_bytes = 0
        cdef const char_type *ptr
        if num_bytes != 0xfe:
            return self.read_bytes(num_bytes)
        if buf is NULL:
            raise Exception("No buffer available for chunked read!")
        while True:
            num_bytes = self.read_uint8()
            if num_bytes == 0:
                break
            if total_num_bytes + num_bytes > max_length_bytes:
                raise Exception("Buffer too small for chunked read!")
            ptr = self._get_raw(num_bytes)
            memcpy(&buf[total_num_bytes], ptr, num_bytes)
            total_num_bytes += num_bytes
        return cpython.PyBytes_FromStringAndSize(<char*> buf, total_num_bytes)

    cdef str read_str(self, ssize_t num_bytes):
        return self.read_bytes(num_bytes).decode()

    cdef str read_nstr(self, ssize_t num_bytes):
        return self.read_bytes(num_bytes).decode("UTF-16BE")

    cdef object read_oracle_number(self, uint8_t num_bytes):
        cdef uint8_t num_digits, byte, digit
        cdef bint is_positive, is_integer
        cdef int16_t decimal_point_index
        cdef const char_type *ptr
        cdef char_type buf[172]
        cdef uint8_t digits[40]
        cdef int8_t exponent
        cdef str text

        # the first byte is the exponent; positive numbers have the highest
        # order bit set, whereas negative numbers have the highest order bit
        # cleared and the bits inverted
        exponent = self.read_uint8()
        is_positive = (exponent & 0x80)
        if not is_positive:
            exponent = ~exponent
        exponent -= 193
        decimal_point_index = exponent * 2 + 2

        # a mantissa length of 0 implies a value of 0 (if positive) or a value
        # of -1e126 (if negative)
        if num_bytes == 1:
            if is_positive:
                return 0
            return -1e126

        # check for the trailing 102 byte for negative numbers and, if present,
        # reduce the number of mantissa digits
        ptr = self._get_raw(num_bytes - 1)
        if not is_positive and ptr[num_bytes - 2] == 102:
            num_bytes -= 1

        # process the mantissa bytes which are the remaining bytes; each
        # mantissa byte is a base-100 digit
        num_digits = 0
        for i in range(num_bytes - 1):

            # positive numbers have 1 added to them; negative numbers are
            # subtracted from the value 101
            byte = ptr[i]
            if is_positive:
                byte -= 1
            else:
                byte = 101 - byte

            # process the first digit; leading zeroes are ignored
            digit = <uint8_t> byte // 10
            if digit == 0 and i == 0:
                decimal_point_index -= 1
            elif digit == 10:
                digits[num_digits] = 1
                digits[num_digits + 1] = 0
                num_digits += 2
                decimal_point_index += 1
            elif digit != 0 or i > 0:
                digits[num_digits] = digit
                num_digits += 1

            # process the second digit; trailing zeroes are ignored
            digit = byte % 10
            if digit != 0 or i < num_bytes - 2:
                digits[num_digits] = digit
                num_digits += 1

        # create string of digits for transformation to Python value
        is_integer = 1
        num_bytes = 0

        # if negative, include the sign
        if not is_positive:
            buf[num_bytes] = 45         # minus sign
            num_bytes += 1

        # if the decimal point index is 0 or less, add the decimal point and
        # any leading zeroes that are needed
        if decimal_point_index <= 0:
            buf[num_bytes] = 48         # zero
            buf[num_bytes + 1] = 46     # decimal point
            num_bytes += 2
            is_integer = 0
            for i in range(decimal_point_index, 0):
                buf[num_bytes] = 48     # zero
                num_bytes += 1

        # add each of the digits
        for i in range(num_digits):
            if i > 0 and i == decimal_point_index:
                buf[num_bytes] = 46     # decimal point
                is_integer = 0
                num_bytes += 1
            buf[num_bytes] = 48 + digits[i]
            num_bytes += 1

        # if the decimal point index exceeds the number of digits, add any
        # trailing zeroes that are needed
        if decimal_point_index > num_digits:
            for i in range(num_digits, decimal_point_index):
                buf[num_bytes] = 48     # zero
                num_bytes += 1

        # convert result to an integer or a decimal number
        text = cpython.PyBytes_FromStringAndSize(<char*> buf,
                                                 num_bytes).decode()
        if is_integer:
            return int(text)
        return decimal.Decimal(text)

    cdef inline void set_size(self, ssize_t size):
        self._size = size


@cython.final
cdef class WriteBuffer:

    cdef:
        ssize_t _allocated_size
        ssize_t _actual_size
        char_type *_data
        int _view_count

    def __cinit__(self):
        self._allocated_size = 0
        self._actual_size = 0
        self._data = NULL
        self._view_count = 0

    def __dealloc__(self):
        if self._data is not NULL:
            cpython.PyMem_Free(self._data)
            self._data = NULL
            self._allocated_size = 0
            self._actual_size = 0
        if self._view_count > 0:
            raise BufferError('Deallocating buffer with attached memoryviews!')

    def __getbuffer__(self, Py_buffer *buf, int flags):
        self._view_count += 1
        cpython.PyBuffer_FillInfo(buf, self, self._data, self._actual_size, 1,
                flags)

    def __releasebuffer__(self, Py_buffer *buf):
        self._view_count -= 1

    cdef inline _ensure_available(self, ssize_t additional_size):
        cdef ssize_t new_size = self._actual_size + additional_size
        if self._view_count > 0:
            raise BufferError('Buffer is used in a memoryview!')
        if new_size > self._allocated_size:
            self._grow(new_size)

    cdef _grow(self, new_size):
        cdef char_type *new_data
        new_size = ((new_size & BUFFER_CHUNK_SIZE) + 1) * BUFFER_CHUNK_SIZE
        new_data = <char_type*> cpython.PyMem_Realloc(<void*> self._data,
                <size_t> new_size)
        if new_data is NULL:
            raise MemoryError
        self._data = new_data
        self._allocated_size = new_size

    cdef write_bytes(self, bytes value):
        cdef char_type *buf
        cdef ssize_t value_len
        cpython.PyBytes_AsStringAndSize(value, <char**> &buf, &value_len)
        self.write_raw(buf, value_len)

    cdef write_raw(self, const char_type *data, ssize_t length):
        self._ensure_available(length)
        memcpy(self._data + self._actual_size, <void*> data, <size_t> length)
        self._actual_size += length

    cdef write_str(self, str value):
        self.write_bytes(value.encode())

    cdef write_uint8(self, uint8_t value):
        self._data[self._actual_size] = value
        self._actual_size += 1

    cdef write_uint16(self, uint16_t value):
        self._ensure_available(2)
        pack_uint16(&self._data[self._actual_size], value)
        self._actual_size += 2

    cdef write_native_uint16(self, uint16_t value):
        self._ensure_available(2)
        memcpy(self._data + self._actual_size, &value, sizeof(uint16_t))
        self._actual_size += 2

    cdef write_uint16_array(self, uint16_t *value, unsigned num_elements):
        self._ensure_available(num_elements * 2)
        for i in range(num_elements):
            pack_uint16(&self._data[self._actual_size], value[i])
            self._actual_size += 2

    cdef write_uint16_at_offset(self, uint16_t value, ssize_t offset):
        if offset + 2 > self._actual_size:
            raise BufferError("Buffer is too small")
        pack_uint16(&self._data[offset], value)

    cdef write_native_uint32(self, uint32_t value):
        self._ensure_available(4)
        memcpy(self._data + self._actual_size, &value, sizeof(uint32_t))
        self._actual_size += 4

    cdef write_uint32(self, uint32_t value):
        self._ensure_available(4)
        pack_uint32(&self._data[self._actual_size], value)
        self._actual_size += 4

    cdef write_native_uint64(self, uint64_t value):
        self._ensure_available(8)
        memcpy(self._data + self._actual_size, &value, sizeof(uint64_t))
        self._actual_size += 8

    cdef write_uint64(self, uint64_t value):
        self._ensure_available(8)
        pack_uint64(&self._data[self._actual_size], value)
        self._actual_size += 8
