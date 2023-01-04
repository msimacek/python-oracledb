#------------------------------------------------------------------------------
# Copyright (c) 2022, Oracle and/or its affiliates.
#
# This software is dual-licensed to you under the Universal Permissive License
# (UPL) 1.0 as shown at https://oss.oracle.com/licenses/upl and Apache License
# 2.0 as shown at http://www.apache.org/licenses/LICENSE-2.0. You may choose
# either license.
#
# If you elect to accept the software under the Apache License, Version 2.0,
# the following applies:
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# transport.pyx
#
# Cython file defining the low-level network transport classes. These serve to
# provide a level of abstraction between the synchronous and asynchronous APIs
# (embedded in thin_impl.pyx).
#------------------------------------------------------------------------------

cdef class BaseTransport:

    cdef:
        object transport
        object socket_fileno

    def __init__(self, transport):
        self.transport = transport

    cdef int _print_packet(self, str operation, bytes data) except -1:
        """
        Print the packet content in a format suitable for debugging.
        """
        offset = 0
        hex_data = memoryview(data).hex().upper()
        now = datetime.datetime.now().isoformat(sep=" ",
                                                timespec="milliseconds")
        lines = [f"{now} [socket: {self.socket_fileno}] {operation}"]
        while hex_data:
            line_hex_data = hex_data[:16]
            hex_data = hex_data[16:]
            hex_dump_values = []
            printable_values = []
            for i in range(0, len(line_hex_data), 2):
                hex_byte = line_hex_data[i:i + 2]
                hex_dump_values.append(hex_byte)
                byte_val = ord(bytes.fromhex(hex_byte))
                char_byte = chr(byte_val)
                if char_byte.isprintable() and byte_val < 128 \
                        and char_byte != " ":
                    printable_values.append(char_byte)
                else:
                    printable_values.append(".")
            while len(hex_dump_values) < 8:
                hex_dump_values.append("  ")
                printable_values.append(" ")
            lines.append(f'{offset:04} : {" ".join(hex_dump_values)} ' + \
                         f'|{"".join(printable_values)}|')
            offset += 8
        lines.append("")
        print("\n".join(lines))

    cdef int _write_packet(self, bytes data) except -1:
        """
        Used for writing packet data to the transport.
        """
        raise NotImplementedError()

    cdef int read_packet(self, uint8_t* packet_type,
                         uint8_t* packet_flags) except -1:
        """
        Reads a packet from the transport.
        """

    cdef int write_packet(self, bytes data) except -1:
        """
        Used for writing packet data to the transport.
        """
        if DEBUG_PACKETS:
            self._print_packet("Sending packet:", data)
        self._write_packet(data)


cdef class AsyncTransport(BaseTransport):

    def __init__(self, transport):
        BaseTransport.__init__(self, transport)
        sock = transport.get_extra_info("socket")
        self._socket_fileno = sock.fileno()

    cdef int _write_packet(self, bytes data) except -1:
        """
        Used for writing packet data to the transport.
        """
        self.transport.write(data)


cdef class SyncTransport(BaseTransport):

    def __init__(self, transport):
        BaseTransport.__init__(self, transport)
        self._socket_fileno = transport.fileno()

    cdef int _write_packet(self, bytes data) except -1:
        """
        Used for writing packet data to the transport.
        """
        try:
            self.transport.send(data)
        except OSError as e:
            errors._raise_err(errors.ERR_CONNECTION_CLOSED, str(e), cause=e)
