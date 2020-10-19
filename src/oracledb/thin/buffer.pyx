#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import decimal

from libc.string cimport memcpy, memset

ctypedef unsigned char char_type

include "hton.pxd"

DEF NUMBER_AS_TEXT_CHARS = 172
DEF NUMBER_MAX_DIGITS = 40
DEF BUFFER_CHUNK_SIZE = 2048
DEF CHUNKED_BYTES_CHUNK_SIZE = 65536

cdef struct BytesChunk:
    char_type *ptr
    uint32_t length
    uint32_t allocated_length


@cython.final
cdef class ChunkedBytesBuffer:

    cdef:
        uint32_t _num_chunks
        uint32_t _allocated_chunks
        BytesChunk *_chunks

    def __dealloc__(self):
        cdef uint32_t i
        for i in range(self._allocated_chunks):
            if self._chunks[i].ptr is not NULL:
                cpython.PyMem_Free(self._chunks[i].ptr)
                self._chunks[i].ptr = NULL
        if self._chunks is not NULL:
            cpython.PyMem_Free(self._chunks)
            self._chunks = NULL

    cdef int _allocate_chunks(self) except -1:
        """
        Allocates a new set of chunks and copies data from the original set of
        chunks if needed.
        """
        cdef:
            BytesChunk *chunks
            uint32_t allocated_chunks
        allocated_chunks = self._allocated_chunks + 8
        chunks = <BytesChunk*> \
                cpython.PyMem_Malloc(sizeof(BytesChunk) * allocated_chunks)
        memset(chunks, 0, sizeof(BytesChunk) * allocated_chunks)
        if self._num_chunks > 0:
            memcpy(chunks, self._chunks, sizeof(BytesChunk) * self._num_chunks)
            cpython.PyMem_Free(self._chunks)
        self._chunks = chunks
        self._allocated_chunks = allocated_chunks

    cdef BytesChunk* _get_chunk(self, uint32_t num_bytes) except NULL:
        """
        Return the chunk that can be used to write the number of bytes
        requested.
        """
        cdef:
            uint32_t num_allocated_bytes
            BytesChunk *chunk
        if self._num_chunks > 0:
            chunk = &self._chunks[self._num_chunks - 1]
            if chunk.allocated_length >= chunk.length + num_bytes:
                return chunk
        if self._num_chunks >= self._allocated_chunks:
            self._allocate_chunks()
        self._num_chunks += 1
        chunk = &self._chunks[self._num_chunks - 1]
        chunk.length = 0
        if chunk.allocated_length < num_bytes:
            num_allocated_bytes = self._get_chunk_size(num_bytes)
            if chunk.ptr:
                cpython.PyMem_Free(chunk.ptr)
            chunk.ptr = <char_type*> cpython.PyMem_Malloc(num_allocated_bytes)
            chunk.allocated_length = num_allocated_bytes
        return chunk

    cdef inline uint32_t _get_chunk_size(self, uint32_t size):
        """
        Returns the size to allocate aligned on a 64K boundary.
        """
        return (size + CHUNKED_BYTES_CHUNK_SIZE - 1) & \
               ~(CHUNKED_BYTES_CHUNK_SIZE - 1)

    cdef bytes end_chunked_read(self):
        """
        Called when a chunked read has ended. Since a chunked read is never
        started until at least some bytes are being read, it is assumed that at
        least one chunk is in use. If one chunk is in use, those bytes are
        returned directly, but if more than one chunk is in use, the first
        chunk is resized to include all of the bytes in a contiguous section of
        memory first.
        """
        cdef:
            uint32_t i, num_allocated_bytes, total_num_bytes = 0, pos = 0
            char_type *ptr
        if self._num_chunks > 1:
            for i in range(self._num_chunks):
                total_num_bytes += self._chunks[i].length
            num_allocated_bytes = self._get_chunk_size(total_num_bytes)
            ptr = <char_type*> cpython.PyMem_Malloc(num_allocated_bytes)
            for i in range(self._num_chunks):
                memcpy(&ptr[pos], self._chunks[i].ptr, self._chunk[i].length)
                pos += self._chunks[i].length
                cpython.PyMem_Free(self._chunks[i].ptr)
                self._chunks[i].ptr = NULL
                self._chunks[i].allocated_length = 0
                self._chunks[i].length = 0
            self._num_chunks = 1
            self._chunks[0].ptr = ptr
            self._chunks[0].length = total_num_bytes
            self._chunks[0].allocated_length = num_allocated_bytes
        return self._chunks[0].ptr[:self._chunks[0].length]

    cdef char_type* get_chunk_ptr(self, uint32_t size_required) except NULL:
        """
        Called when memory is required for a chunked read.
        """
        cdef:
            BytesChunk *chunk
            char_type *ptr
        chunk = self._get_chunk(size_required)
        ptr = &chunk.ptr[chunk.length]
        chunk.length += size_required
        return ptr

    cdef inline void start_chunked_read(self):
        """
        Called when a chunked read is started and simply indicates that no
        chunks are in use. The memory is retained in order to reduce the
        overhead in freeing and reallocating memory for each chunked read.
        """
        self._num_chunks = 0


@cython.final
cdef class ReadBuffer:

    cdef:
        const char_type *_data
        ssize_t _size
        ssize_t _offset
        int _view_count

    def __cinit__(self, const char_type[:] data, ssize_t size):
        self._data = &data[0]
        self._size = size
        self._offset = 0

    def __getbuffer__(self, Py_buffer *buf, int flags):
        self._view_count += 1
        cpython.PyBuffer_FillInfo(buf, self, <char*> self._data, self._size, 1,
                flags)

    def __releasebuffer__(self, Py_buffer *buf):
        self._view_count -= 1

    cdef int _convert_base64(self, bytearray result, long value, int size,
                             int offset):
        """
        Converts every 6 bits into a character, from left to right. This is
        similar to ordinary base64 encoding with a few differences and written
        here for performance.
        """
        cdef int i
        for i in range(size):
            result[offset + size - i - 1] = \
                    TNS_BASE64_ALPHABET_ARRAY[value & 0x3f]
            value = value >> 6
        return offset + size

    cdef inline const char_type* _get_raw(self, ssize_t num_bytes) except NULL:
        cdef const char_type *ptr = &self._data[self._offset]
        if self._offset + num_bytes > self._size:
            raise BufferError('Not enough data in buffer!')
        self._offset += num_bytes
        return ptr

    cdef ssize_t bytes_left(self):
        return self._size - self._offset

    cdef int skip_bytes(self, ssize_t num_bytes) except -1:
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

    cdef int16_t read_int16(self) except *:
        return <int16_t> self.read_uint16()

    cdef uint32_t read_uint32(self) except *:
        cdef const char_type *ptr = self._get_raw(4)
        return unpack_uint32(ptr)

    cdef uint32_t read_uint64(self) except *:
        cdef const char_type *ptr = self._get_raw(8)
        return unpack_uint64(ptr)

    cdef int32_t read_int32(self) except *:
        return <int32_t> self.read_uint32()

    cdef inline uint16_t read_ub2(self) except *:
        return <uint16_t> self.read_oracle_int()

    cdef inline uint32_t read_ub4(self) except *:
        return <uint32_t> self.read_oracle_int()

    cdef uint64_t read_ub8(self) except *:
        return <uint64_t> self.read_oracle_int()

    cdef bytes read_bytes(self, ssize_t num_bytes):
        cdef const char_type *ptr = self._get_raw(num_bytes)
        return cpython.PyBytes_FromStringAndSize(<char*> ptr, num_bytes)

    cdef bytes read_bytes_chunked(self, uint32_t num_bytes,
                                  ChunkedBytesBuffer chunked_bytes_buf):
        cdef:
            const char_type *source_ptr
            char_type *dest_ptr
        if num_bytes != 0xfe:
            return self.read_bytes(num_bytes)
        chunked_bytes_buf.start_chunked_read()
        while True:
            num_bytes = self.read_ub4()
            if num_bytes == 0:
                break
            source_ptr = self._get_raw(num_bytes)
            dest_ptr = chunked_bytes_buf.get_chunk_ptr(num_bytes)
            memcpy(dest_ptr, source_ptr, num_bytes)
        return chunked_bytes_buf.end_chunked_read()

    cdef str read_str(self, ssize_t num_bytes):
        return self.read_bytes(num_bytes).decode()

    cdef str read_nstr(self, ssize_t num_bytes):
        return self.read_bytes(num_bytes).decode("UTF-16BE")

    cdef object read_oracle_date(self, uint8_t num_bytes):
        cdef:
            const char_type *ptr = self._get_raw(num_bytes)
            uint32_t fsecond = 0
            uint16_t year
        year = (<uint8_t> ptr[0] - 100) * 100 + <uint8_t> ptr[1] - 100
        if num_bytes >= 11:
            fsecond = unpack_uint32(&ptr[7]) // 1000
        return cydatetime.datetime_new(year, ptr[2], ptr[3], ptr[4] - 1,
                                       ptr[5] - 1, ptr[6] - 1, fsecond, None)

    cdef int64_t read_oracle_int(self) except *:
        cdef:
            bint is_negative = False
            uint8_t length
            int64_t value
        length = self.read_uint8()
        if length & 0x80:
            is_negative = True
            length = length & 0x7f
        if length == 0:
            return 0
        elif length == 1:
            value = self.read_uint8()
        elif length == 2:
            value = self.read_uint16()
        elif length == 3:
            value = self.read_uint16() * 256 + self.read_uint8()
        elif length == 4:
            value = self.read_uint32()
        elif length == 8:
            value = self.read_uint64()
        else:
            raise Exception(f"TTC error: read integer of length {length}")
        if is_negative:
            value = -value
        return value

    cdef object read_oracle_number(self, uint8_t num_bytes):
        cdef uint8_t num_digits, byte, digit
        cdef bint is_positive, is_integer
        cdef int16_t decimal_point_index
        cdef const char_type *ptr
        cdef char_type buf[NUMBER_AS_TEXT_CHARS]
        cdef uint8_t digits[NUMBER_MAX_DIGITS]
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

    cdef object read_rowid(self):
        cdef:
            bytearray result
            int offset = 0
        result = bytearray(TNS_MAX_ROWID_LENGTH)
        offset = self._convert_base64(result, self.read_ub4(), 6, offset)
        offset = self._convert_base64(result, self.read_ub2(), 3, offset)
        self.skip_bytes(1)
        offset = self._convert_base64(result, self.read_ub4(), 6, offset)
        offset = self._convert_base64(result, self.read_ub2(), 3, offset)
        return bytes(result).decode()

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

    cdef inline int _ensure_available(self, ssize_t additional_size) except -1:
        cdef ssize_t new_size = self._actual_size + additional_size
        if self._view_count > 0:
            raise BufferError('Buffer is used in a memoryview!')
        if new_size > self._allocated_size:
            self._grow(new_size)

    cdef int _grow(self, new_size) except -1:
        cdef char_type *new_data
        new_size = ((new_size & BUFFER_CHUNK_SIZE) + 1) * BUFFER_CHUNK_SIZE
        new_data = <char_type*> cpython.PyMem_Realloc(<void*> self._data,
                <size_t> new_size)
        if new_data is NULL:
            raise MemoryError
        self._data = new_data
        self._allocated_size = new_size

    cdef int write_bytes(self, bytes value) except -1:
        cdef char_type *buf
        cdef ssize_t value_len
        cpython.PyBytes_AsStringAndSize(value, <char**> &buf, &value_len)
        self.write_raw(buf, value_len)

    cdef int write_oracle_date(self, object value, uint8_t length) except -1:
        cdef:
            unsigned int year
            char_type buf[13]
            uint32_t fsecond
        self.write_uint8(length)
        year = cydatetime.datetime_year(value)
        buf[0] = <uint8_t> ((year // 100) + 100)
        buf[1] = <uint8_t> ((year % 100) + 100)
        buf[2] = <uint8_t> cydatetime.datetime_month(value)
        buf[3] = <uint8_t> cydatetime.datetime_day(value)
        buf[4] = <uint8_t> cydatetime.datetime_hour(value) + 1
        buf[5] = <uint8_t> cydatetime.datetime_minute(value) + 1
        buf[6] = <uint8_t> cydatetime.datetime_second(value) + 1
        if length > 7:
            fsecond = <uint32_t> cydatetime.datetime_microsecond(value) * 1000
            pack_uint32(&buf[7], fsecond)
        if length > 11:
            pack_uint16(&buf[11], 0)
        self.write_raw(buf, length)

    cdef int write_oracle_number(self, bytes num_bytes) except -1:
        cdef:
            uint8_t num_digits = 0, digit, num_pairs, pair_num, digits_pos
            bint exponent_is_negative = False, append_sentinel = False
            ssize_t num_bytes_length, exponent_pos, pos = 0
            bint is_negative = False, prepend_zero = False
            uint8_t digits[NUMBER_AS_TEXT_CHARS]
            int16_t decimal_point_index
            int8_t exponent_on_wire
            const char_type *ptr
            int16_t exponent

        # zero length string cannot be converted
        num_bytes_length = len(num_bytes)
        if num_bytes_length == 0:
            raise Exception("zero length string representation of number")
        elif num_bytes_length > NUMBER_AS_TEXT_CHARS:
            raise Exception("string representation of number too long")

        # check to see if number is negative (first character is '-')
        ptr = num_bytes
        if ptr[0] == b'-':
            is_negative = True
            pos += 1

        # scan for digits until the decimal point or exponent indicator found
        while pos < num_bytes_length:
            if ptr[pos] == b'.' or ptr[pos] == b'e' or ptr[pos] == b'E':
                break
            if ptr[pos] < b'0' or ptr[pos] > b'9':
                raise Exception("invalid string representation of number")
            digit = ptr[pos] - <uint8_t> b'0'
            pos += 1
            if digit == 0 and num_digits == 0:
                continue
            digits[num_digits] = digit
            num_digits += 1
        decimal_point_index = num_digits

        # scan for digits following the decimal point, if applicable
        if pos < num_bytes_length and ptr[pos] == b'.':
            pos += 1
            while pos < num_bytes_length:
                if ptr[pos] == b'e' or ptr[pos] == b'E':
                    break
                digit = ptr[pos] - <uint8_t> b'0'
                pos += 1
                if digit == 0 and num_digits == 0:
                    decimal_point_index -= 1
                    continue
                digits[num_digits] = digit
                num_digits += 1

        # handle exponent, if applicable
        if pos < num_bytes_length and (ptr[pos] == b'e' or ptr[pos] == b'E'):
            pos += 1
            if pos < num_bytes_length:
                if ptr[pos] == b'-':
                    exponent_is_negative = True
                    pos += 1
                elif ptr[pos] == b'+':
                    pos += 1
            exponent_pos = pos
            while pos < num_bytes_length:
                if ptr[pos] < b'0' or ptr[pos] > b'9':
                    raise Exception("invalid exponent")
                pos += 1
            if exponent_pos == pos:
                raise Exception("no digits in exponent")
            exponent = <int16_t> int(ptr[exponent_pos:pos])
            if exponent_is_negative:
                exponent = -exponent
            decimal_point_index += exponent

        # if there is anything left in the string, that indicates an invalid
        # number as well
        if pos < num_bytes_length:
            raise Exception("invalid number")

        # skip trailing zeros
        while num_digits > 0 and digits[num_digits - 1] == 0:
            num_digits -= 1

        # value must be less than 1e126 and greater than 1e-129; the number of
        # digits also cannot exceed the maximum precision of Oracle numbers
        if num_digits > NUMBER_MAX_DIGITS or decimal_point_index > 126 \
                or decimal_point_index < -129:
            raise Exception("value cannot be represented as an Oracle number")

        # if the exponent is odd, prepend a zero
        if (decimal_point_index > 0 and decimal_point_index % 2 == 1) \
                or (decimal_point_index < 0 and decimal_point_index % 2 == -1):
            prepend_zero = True
            if num_digits > 0:
                digits[num_digits] = 0
                num_digits += 1
                decimal_point_index += 1

        # determine the number of digit pairs; if the number of digits is odd,
        # append a zero to make the number of digits even
        if num_digits % 2 == 1:
            digits[num_digits] = 0
            num_digits += 1
        num_pairs = num_digits // 2

        # append a sentinel 102 byte for negative numbers if there is room
        if is_negative and num_digits > 0 and num_digits < NUMBER_MAX_DIGITS:
            append_sentinel = True

        # write length of number
        self.write_uint8(num_pairs + 1 + append_sentinel)

        # if the number of digits is zero, the value is itself zero since all
        # leading and trailing zeros are removed from the digits string; this
        # is a special case
        if num_digits == 0:
            self.write_uint8(128)
            return 0

        # write the exponent
        exponent_on_wire = <int8_t> ((decimal_point_index - 2) / 2 + 193)
        if is_negative:
            exponent_on_wire = ~exponent_on_wire
        self.write_uint8(exponent_on_wire)

        # write the mantissa bytes
        digits_pos = 0
        for pair_num in range(num_pairs):
            if pair_num == 0 and prepend_zero:
                digit = digits[digits_pos]
                digits_pos += 1
            else:
                digit = digits[digits_pos] * 10 + digits[digits_pos + 1]
                digits_pos += 2
            if is_negative:
                digit = 101 - digit
            else:
                digit += 1
            self.write_uint8(digit)

        # append 102 byte for negative numbers if the number of digits is less
        # than the maximum allowable
        if append_sentinel:
            self.write_uint8(102)

    cdef int write_raw(self, const char_type *data, ssize_t length) except -1:
        self._ensure_available(length)
        memcpy(self._data + self._actual_size, <void*> data, <size_t> length)
        self._actual_size += length

    cdef int write_str(self, str value) except -1:
        self.write_bytes(value.encode())

    cdef int write_uint8(self, uint8_t value) except -1:
        self._data[self._actual_size] = value
        self._actual_size += 1

    cdef int write_uint16(self, uint16_t value) except -1:
        self._ensure_available(2)
        pack_uint16(&self._data[self._actual_size], value)
        self._actual_size += 2

    cdef int write_uint16_at_offset(self, uint16_t value,
                                    ssize_t offset) except -1:
        if offset + 2 > self._actual_size:
            raise BufferError("Buffer is too small")
        pack_uint16(&self._data[offset], value)

    cdef int write_uint32(self, uint32_t value) except -1:
        self._ensure_available(4)
        pack_uint32(&self._data[self._actual_size], value)
        self._actual_size += 4

    cdef int write_uint64(self, uint64_t value) except -1:
        self._ensure_available(8)
        pack_uint64(&self._data[self._actual_size], value)
        self._actual_size += 8

    cdef int write_ub4(self, uint32_t value) except -1:
        if value == 0:
            self.write_uint8(0)
        elif value <= UINT8_MAX:
            self.write_uint8(1)
            self.write_uint8(<uint8_t> value)
        elif value <= UINT16_MAX:
            self.write_uint8(2)
            self.write_uint16(<uint16_t> value)
        else:
            self.write_uint8(4)
            self.write_uint32(value)
