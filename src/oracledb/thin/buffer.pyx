#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

import decimal

from libc.string cimport memcpy, memset

ctypedef unsigned char char_type

include "bswap.pxd"

DEF PACKET_HEADER_SIZE = 8
DEF NUMBER_AS_TEXT_CHARS = 172
DEF NUMBER_MAX_DIGITS = 40
DEF BUFFER_CHUNK_SIZE = 65536
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
                memcpy(&ptr[pos], self._chunks[i].ptr, self._chunks[i].length)
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
        ssize_t _max_packet_size, _max_size, _size, _offset, _bytes_to_process
        ChunkedBytesBuffer _chunked_bytes_buf
        ssize_t _packet_start_offset
        const char_type *_data
        bytearray _data_obj
        Capabilities _caps
        int _view_count
        object _socket

    def __cinit__(self, object sock, ssize_t max_packet_size,
                  Capabilities caps):
        self._socket = sock
        self._caps = caps
        self._max_size = max_packet_size * 2
        self._max_packet_size = max_packet_size
        self._data_obj = bytearray(self._max_size)
        self._data = <const char_type*> self._data_obj
        self._chunked_bytes_buf = ChunkedBytesBuffer()

    def __getbuffer__(self, Py_buffer *buf, int flags):
        cdef char* ptr = <char*> &self._data[self._packet_start_offset]
        self._view_count += 1
        cpython.PyBuffer_FillInfo(buf, self, ptr,
                                  self._size - self._packet_start_offset, 1,
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
        """
        Returns a pointer to the buffer after ensuring that the specified
        number of bytes are available.
        """
        cdef const char_type *ptr = &self._data[self._offset]
        if self._offset + num_bytes > self._size:
            msg = f"Not enough data in buffer: need {num_bytes} bytes!"
            raise BufferError(msg)
        self._offset += num_bytes
        return ptr

    cdef int _read_split_bytes(self, uint32_t num_bytes_1,
                               uint32_t num_bytes_2) except -1:
        cdef:
            const char_type *source_ptr
            char_type *dest_ptr
            uint8_t packet_type
        dest_ptr = self._chunked_bytes_buf.get_chunk_ptr(num_bytes_1)
        source_ptr = self._get_raw(num_bytes_1)
        memcpy(dest_ptr, source_ptr, num_bytes_1)
        self.receive_packet(&packet_type)
        self.skip_bytes(2)                  # skip data flags
        dest_ptr = self._chunked_bytes_buf.get_chunk_ptr(num_bytes_2)
        source_ptr = self._get_raw(num_bytes_2)
        memcpy(dest_ptr, source_ptr, num_bytes_2)

    cdef inline ssize_t bytes_left(self):
        return self._size - self._offset

    cdef int receive_packet(self, uint8_t *packet_type) except -1:
        """
        Receives a packet and updates the pointers appropriately. Note that
        multiple packets may be received if they are small enough or a portion
        of a second packet may be received so the buffer needs to be adjusted
        as needed. This is also why room is available in the buffer for up to
        two complete packets.
        """
        cdef:
            ssize_t offset, bytes_to_read, packet_size
            char_type[:] view

        # if no bytes are left over from a previous read, perform a read of the
        # maximum packet size and reset the offset to 0
        view = memoryview(self._data_obj)
        if self._bytes_to_process == 0:
            self._packet_start_offset = 0
            self._offset = 0
            self._bytes_to_process = \
                    self._socket.recv_into(self._data_obj,
                                           self._max_packet_size)

        # otherwise, set the offset to the end of the previous packet and
        # ensure that there are at least enough bytes available to cover the
        # contents of the packet header
        else:
            self._packet_start_offset = self._size
            self._offset = self._size
            if self._bytes_to_process < PACKET_HEADER_SIZE:
                offset = self._size + self._bytes_to_process
                bytes_to_read = PACKET_HEADER_SIZE - self._bytes_to_process
                self._bytes_to_process += \
                        self._socket.recv_into(view[offset:], bytes_to_read)

        # determine the packet length and ensure that all of the bytes for the
        # packet are available; note that as of version 12.2 the packet size is
        # 32 bits in size instead of 16 bits, but this doesn't take effect
        # until it is known that the server is capable of that as well
        if self._caps.protocol_version >= TNS_VERSION_MIN_LARGE_SDU:
            self._size += 4
            packet_size = self.read_uint32()
        else:
            self._size += 2
            packet_size = self.read_uint16()
        while self._bytes_to_process < packet_size:
            offset = self._packet_start_offset + self._bytes_to_process
            bytes_to_read = packet_size - self._bytes_to_process
            self._bytes_to_process += \
                    self._socket.recv_into(view[offset:], bytes_to_read)

        # process remainder of packet header and set size to the new packet
        self._size = self._packet_start_offset + packet_size
        self._bytes_to_process -= packet_size
        if self._caps.protocol_version < TNS_VERSION_MIN_LARGE_SDU:
            self.skip_bytes(2)          # skip packet checksum
        packet_type[0] = self.read_uint8()
        self.skip_bytes(3)              # skip reserved byte, header checksum

        # display packet if requested
        if DEBUG_PACKETS:
            _print_packet("Receiving packet:", memoryview(self))

    cdef int skip_bytes(self, ssize_t num_bytes) except -1:
        self._get_raw(num_bytes)

    cdef void unread_bytes(self, ssize_t num_bytes):
        self._offset -= num_bytes
        if self._offset < 0:
            self._offset = 0

    cdef object read_binary_double(self):
        cdef:
            const uint8_t *ptr = <uint8_t*> self._get_raw(8)
            uint64_t high_bits, low_bits, all_bits
            uint8_t b0, b1, b2, b3, b4, b5, b6, b7
            double *double_ptr
        b0 = ptr[0]
        b1 = ptr[1]
        b2 = ptr[2]
        b3 = ptr[3]
        b4 = ptr[4]
        b5 = ptr[5]
        b6 = ptr[6]
        b7 = ptr[7]
        if b0 & 0x80:
            b0 = b0 & 0x7f
        else:
            b0 = ~b0
            b1 = ~b1
            b2 = ~b2
            b3 = ~b3
            b4 = ~b4
            b5 = ~b5
            b6 = ~b6
            b7 = ~b7
        high_bits = b0 << 24 | b1 << 16 | b2 << 8 | b3
        low_bits = b4 << 24 | b5 << 16 | b6 << 8 | b7
        all_bits = high_bits << 32 | (low_bits & 0xffffffff)
        double_ptr = <double*> &all_bits
        ptr = <uint8_t*> double_ptr
        return double_ptr[0]

    cdef object read_binary_float(self):
        cdef:
            const uint8_t *ptr = <uint8_t*> self._get_raw(4)
            uint8_t b0, b1, b2, b3
            uint64_t all_bits
            float *float_ptr
        b0 = ptr[0]
        b1 = ptr[1]
        b2 = ptr[2]
        b3 = ptr[3]
        if b0 & 0x80:
            b0 = b0 & 0x7f
        else:
            b0 = ~b0
            b1 = ~b1
            b2 = ~b2
            b3 = ~b3
        all_bits = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
        float_ptr = <float*> &all_bits
        ptr = <uint8_t*> float_ptr
        return float_ptr[0]

    cdef uint8_t read_uint8(self) except *:
        cdef const char_type *ptr = self._get_raw(1)
        return ptr[0]

    cdef int8_t read_int8(self) except *:
        return <int8_t> self.read_uint8()

    cdef uint16_t read_uint16(self, byte_order=BYTE_ORDER_MSB) except *:
        cdef const char_type *ptr = self._get_raw(2)
        return unpack_uint16(ptr, byte_order)

    cdef uint32_t read_uint32(self, byte_order=BYTE_ORDER_MSB) except *:
        cdef const char_type *ptr = self._get_raw(4)
        return unpack_uint32(ptr, byte_order)

    cdef uint32_t read_uint64(self, byte_order=BYTE_ORDER_MSB) except *:
        cdef const char_type *ptr = self._get_raw(8)
        return unpack_uint64(ptr, byte_order)

    cdef inline uint16_t read_ub2(self) except *:
        return <uint16_t> self.read_oracle_int()

    cdef inline uint32_t read_ub4(self) except *:
        return <uint32_t> self.read_oracle_int()

    cdef uint64_t read_ub8(self) except *:
        return <uint64_t> self.read_oracle_int()

    cdef bytes read_bytes(self, ssize_t num_bytes):
        cdef:
            const char_type *source_ptr
            uint32_t num_bytes_left
            char_type *dest_ptr
        if num_bytes != TNS_LONG_LENGTH_INDICATOR:
            num_bytes_left = <uint32_t> self.bytes_left()
            if num_bytes <= num_bytes_left:
                source_ptr = self._get_raw(num_bytes)
                return source_ptr[:num_bytes]
            self._chunked_bytes_buf.start_chunked_read()
            self._read_split_bytes(num_bytes_left, num_bytes - num_bytes_left)
            return self._chunked_bytes_buf.end_chunked_read()
        self._chunked_bytes_buf.start_chunked_read()
        while True:
            num_bytes = self.read_ub4()
            if num_bytes == 0:
                break
            num_bytes_left = <uint32_t> self.bytes_left()
            if num_bytes < num_bytes_left:
                source_ptr = self._get_raw(num_bytes)
                dest_ptr = self._chunked_bytes_buf.get_chunk_ptr(num_bytes)
                memcpy(dest_ptr, source_ptr, num_bytes)
            else:
                self._read_split_bytes(num_bytes_left,
                                       num_bytes - num_bytes_left)
        return self._chunked_bytes_buf.end_chunked_read()

    cdef object read_interval_ds(self, uint8_t num_bytes):
        cdef:
            uint32_t days, hours, minutes, second, total_seconds, fseconds
            const uint8_t *ptr = <uint8_t*> self._get_raw(num_bytes)
        days = unpack_uint32(ptr, BYTE_ORDER_MSB) - TNS_DURATION_MID
        fseconds = unpack_uint32(&ptr[7], BYTE_ORDER_MSB) - TNS_DURATION_MID
        hours = ptr[4] - TNS_DURATION_OFFSET
        minutes = ptr[5] - TNS_DURATION_OFFSET
        seconds = ptr[6] - TNS_DURATION_OFFSET
        total_seconds = hours * 60 * 60 + minutes * 60 + seconds
        return cydatetime.timedelta_new(days, total_seconds, fseconds // 1000)

    cdef str read_str(self, ssize_t num_bytes):
        return self.read_bytes(num_bytes).decode()

    cdef object read_oracle_date(self, uint8_t num_bytes):
        cdef:
            const char_type *ptr = self._get_raw(num_bytes)
            uint32_t fsecond = 0
            uint16_t year
        year = (<uint8_t> ptr[0] - 100) * 100 + <uint8_t> ptr[1] - 100
        if num_bytes >= 11:
            fsecond = unpack_uint32(&ptr[7], BYTE_ORDER_MSB) // 1000
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
            uint16_t partition_id, slot_num
            uint32_t rba, block_num
            bytearray result
            int offset = 0
        rba = self.read_ub4()
        partition_id = self.read_ub2()
        self.skip_bytes(1)
        block_num = self.read_ub4()
        slot_num = self.read_ub2()
        if rba != 0 or partition_id != 0 or block_num != 0 or slot_num != 0:
            result = bytearray(TNS_MAX_ROWID_LENGTH)
            offset = self._convert_base64(result, rba, 6, offset)
            offset = self._convert_base64(result, partition_id, 3, offset)
            offset = self._convert_base64(result, block_num, 6, offset)
            offset = self._convert_base64(result, slot_num, 3, offset)
            return bytes(result).decode()

    cdef object read_urowid(self, bytes input_bytes):
        cdef:
            ssize_t output_len, input_len, remainder, pos
            int input_offset = 1, output_offset = 0
            bytearray input_value, output_value
        input_len = len(input_bytes)
        output_len = (input_len // 3) * 4
        remainder = input_len % 3
        if remainder == 1:
            output_len += 1
        elif remainder == 2:
            output_len += 3
        input_value = bytearray(input_bytes)
        output_value = bytearray(output_len)
        input_len -= 1
        output_value[0] = 42            # '*'
        output_offset += 1
        while input_len > 0:

            # produce first byte of quadruple
            pos = input_value[input_offset] >> 2
            output_value[output_offset] = TNS_BASE64_ALPHABET_ARRAY[pos]
            output_offset += 1

            # produce second byte of quadruple, but if only one byte is left,
            # produce that one byte and exit
            pos = (input_value[input_offset] & 0x3) << 4
            if input_len == 1:
                output_value[output_offset] = TNS_BASE64_ALPHABET_ARRAY[pos]
                break
            input_offset += 1
            pos |= ((input_value[input_offset] & 0xf0) >> 4)
            output_value[output_offset] = TNS_BASE64_ALPHABET_ARRAY[pos]
            output_offset += 1

            # produce third byte of quadruple, but if only two bytes are left,
            # produce that one byte and exit
            pos = (input_value[input_offset] & 0xf) << 2
            if input_len == 2:
                output_value[output_offset] = TNS_BASE64_ALPHABET_ARRAY[pos]
                break
            input_offset += 1
            pos |= ((input_value[input_offset] & 0xc0) >> 6)
            output_value[output_offset] = TNS_BASE64_ALPHABET_ARRAY[pos]
            output_offset += 1

            # produce final byte of quadruple
            pos = input_value[input_offset] & 0x3f
            output_value[output_offset] = TNS_BASE64_ALPHABET_ARRAY[pos]
            output_offset += 1
            input_offset += 1
            input_len -= 3

        return bytes(output_value).decode()


@cython.final
cdef class WriteBuffer:

    cdef:
        ssize_t _max_size, _actual_size
        uint8_t _packet_type
        bytearray _data_obj
        Capabilities _caps
        char_type *_data
        object _socket
        int _view_count
        uint8_t _seq_num

    def __cinit__(self, object sock, ssize_t max_size, Capabilities caps):
        self._socket = sock
        self._caps = caps
        self._data_obj = bytearray(max_size)
        self._data = <char_type*> self._data_obj
        self._max_size = max_size

    def __dealloc__(self):
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
        if new_size > self._max_size:
            self._send_packet()
            self.write_uint16(0)            # data flags for next packet

    cdef int _send_packet(self) except -1:
        """
        Write the packet header and then send the packet. Once sent, reset the
        pointers back to an empty packet.
        """
        cdef ssize_t size = self._actual_size
        self._actual_size = 0
        if self._caps.protocol_version >= TNS_VERSION_MIN_LARGE_SDU:
            self.write_uint32(size)
        else:
            self.write_uint16(size)
            self.write_uint16(0)
        self.write_uint8(self._packet_type)
        self.write_uint8(0)
        self.write_uint16(0)
        self._actual_size = size
        if DEBUG_PACKETS:
            _print_packet("Sending packet:", memoryview(self))
        self._socket.send(memoryview(self))
        self._actual_size = PACKET_HEADER_SIZE

    cdef inline ssize_t bytes_left(self):
        return self._max_size - self._actual_size

    cdef int end_request(self) except -1:
        """
        Indicates that the request from the client is completing and will send
        any packet remaining, if necessary.
        """
        if self._actual_size > PACKET_HEADER_SIZE:
            self._send_packet()

    cdef inline ssize_t max_payload_bytes(self):
        return self._max_size - PACKET_HEADER_SIZE - 2

    cdef void start_request(self, uint8_t packet_type, uint16_t data_flags=0):
        """
        Indicates that a request from the client is starting. The packet type
        is retained just in case a request spans multiple packets. The packet
        header (8 bytes in length) is written when a packet is actually being
        sent and so is skipped at this point"""
        self._packet_type = packet_type
        self._actual_size = PACKET_HEADER_SIZE
        if packet_type == TNS_PACKET_TYPE_DATA:
            self.write_uint16(data_flags)

    cdef int write_binary_double(self, double value) except -1:
        cdef:
            uint8_t b0, b1, b2, b3, b4, b5, b6, b7
            uint64_t all_bits
            char_type buf[8]
            uint64_t *ptr
        ptr = <uint64_t*> &value
        all_bits = ptr[0]
        b7 = all_bits & 0xff
        b6 = (all_bits >> 8) & 0xff
        b5 = (all_bits >> 16) & 0xff
        b4 = (all_bits >> 24) & 0xff
        b3 = (all_bits >> 32) & 0xff
        b2 = (all_bits >> 40) & 0xff
        b1 = (all_bits >> 48) & 0xff
        b0 = (all_bits >> 56) & 0xff
        if b0 & 0x80 == 0:
            b0 = b0 | 0x80
        else:
            b0 = ~b0
            b1 = ~b1
            b2 = ~b2
            b3 = ~b3
            b4 = ~b4
            b5 = ~b5
            b6 = ~b6
            b7 = ~b7
        buf[0] = b0
        buf[1] = b1
        buf[2] = b2
        buf[3] = b3
        buf[4] = b4
        buf[5] = b5
        buf[6] = b6
        buf[7] = b7
        self.write_uint8(8)
        self.write_raw(buf, 8)

    cdef int write_binary_float(self, float value) except -1:
        cdef:
            uint8_t b0, b1, b2, b3
            uint32_t all_bits
            char_type buf[4]
            uint32_t *ptr
        ptr = <uint32_t*> &value
        all_bits = ptr[0]
        b3 = all_bits & 0xff
        b2 = (all_bits >> 8) & 0xff
        b1 = (all_bits >> 16) & 0xff
        b0 = (all_bits >> 24) & 0xff
        if b0 & 0x80 == 0:
            b0 = b0 | 0x80
        else:
            b0 = ~b0
            b1 = ~b1
            b2 = ~b2
            b3 = ~b3
        buf[0] = b0
        buf[1] = b1
        buf[2] = b2
        buf[3] = b3
        self.write_uint8(4)
        self.write_raw(buf, 4)

    cdef int write_bytes(self, bytes value) except -1:
        cdef:
            ssize_t value_len
            char_type *ptr
        cpython.PyBytes_AsStringAndSize(value, <char**> &ptr, &value_len)
        self.write_raw(ptr, value_len)

    cdef int write_bytes_chunked(self, bytes value) except -1:
        cdef:
            ssize_t value_len, bytes_left
            char_type *ptr
        cpython.PyBytes_AsStringAndSize(value, <char**> &ptr, &value_len)
        if value_len <= TNS_MAX_SHORT_LENGTH:
            self.write_uint8(<uint8_t> value_len)
            self.write_raw(ptr, value_len)
        else:
            self.write_uint8(TNS_LONG_LENGTH_INDICATOR)
            self.write_ub4(value_len)
            bytes_left = self.bytes_left()
            while True:
                if bytes_left >= value_len:
                    self.write_raw(ptr, value_len)
                    break
                self.write_raw(ptr, bytes_left)
                value_len -= bytes_left
                ptr += bytes_left
                bytes_left = self.max_payload_bytes()
            self.write_ub4(0)

    cdef int write_interval_ds(self, object value) except -1:
        cdef:
            uint32_t days, seconds, fseconds
            char_type buf[11]
        days = cydatetime.timedelta_days(value)
        pack_uint32(buf, days + TNS_DURATION_MID, BYTE_ORDER_MSB)
        seconds = cydatetime.timedelta_seconds(value)
        buf[4] = (seconds // 3600) + TNS_DURATION_OFFSET
        seconds = seconds % 3600
        buf[5] = (seconds // 60) + TNS_DURATION_OFFSET
        buf[6] = (seconds % 60) + TNS_DURATION_OFFSET
        fseconds = cydatetime.timedelta_microseconds(value) * 1000
        pack_uint32(&buf[7], fseconds + TNS_DURATION_MID, BYTE_ORDER_MSB)
        self.write_uint8(sizeof(buf))
        self.write_raw(buf, sizeof(buf))

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
            pack_uint32(&buf[7], fsecond, BYTE_ORDER_MSB)
        if length > 11:
            pack_uint16(&buf[11], 0, BYTE_ORDER_MSB)
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

    cdef int write_seq_num(self) except -1:
        self._seq_num += 1
        if self._seq_num == 0:
            self._seq_num = 1
        self.write_uint8(self._seq_num)

    cdef int write_str(self, str value) except -1:
        self.write_bytes(value.encode())

    cdef int write_uint8(self, uint8_t value) except -1:
        self._data[self._actual_size] = value
        self._actual_size += 1

    cdef int write_uint16(self, uint16_t value,
                          int byte_order=BYTE_ORDER_MSB) except -1:
        self._ensure_available(2)
        pack_uint16(&self._data[self._actual_size], value, byte_order)
        self._actual_size += 2

    cdef int write_uint32(self, uint32_t value,
                          int byte_order=BYTE_ORDER_MSB) except -1:
        self._ensure_available(4)
        pack_uint32(&self._data[self._actual_size], value, byte_order)
        self._actual_size += 4

    cdef int write_uint64(self, uint64_t value,
                          byte_order=BYTE_ORDER_MSB) except -1:
        self._ensure_available(8)
        pack_uint64(&self._data[self._actual_size], value, byte_order)
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

    cdef int write_ub8(self, uint64_t value) except -1:
        if value == 0:
            self.write_uint8(0)
        elif value <= UINT8_MAX:
            self.write_uint8(1)
            self.write_uint8(<uint8_t> value)
        elif value <= UINT16_MAX:
            self.write_uint8(2)
            self.write_uint16(<uint16_t> value)
        elif value <= UINT32_MAX:
            self.write_uint8(4)
            self.write_uint32(value)
        else:
            self.write_uint8(8)
            self.write_uint64(value)
