#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

# magic value used to recognize network data
DEF TNS_NETWORK_MAGIC = 0xdeadbeef

# version used for network packets (11.2.0.2.0)
DEF TNS_NETWORK_VERSION = 0xb200200

# network data types
DEF TNS_NETWORK_TYPE_RAW = 1
DEF TNS_NETWORK_TYPE_UB2 = 3
DEF TNS_NETWORK_TYPE_VERSION = 5
DEF TNS_NETWORK_TYPE_STATUS = 6

# network service numbers
DEF TNS_NETWORK_SERVICE_AUTH = 1
DEF TNS_NETWORK_SERVICE_ENCRYPTION = 2
DEF TNS_NETWORK_SERVICE_DATA_INTEGRITY = 3
DEF TNS_NETWORK_SERVICE_SUPERVISOR = 4

# network header sizes
DEF TNS_NETWORK_HEADER_SIZE = 4 + 2 + 4 + 2 + 1
DEF TNS_NETWORK_SERVICE_HEADER_SIZE = 2 + 2 + 4

# network supervisor service constants
DEF TNS_NETWORK_SUPERVISOR_CID = 0x0000101c66ec28ea

# network authentication service constants
DEF TNS_NETWORK_AUTH_TYPE_CLIENT_SERVER = 0xe0e1
DEF TNS_NETWORK_AUTH_STATUS_NOT_REQUIRED = 0xfcff

# network data integrity service constants
DEF TNS_NETWORK_DATA_INTEGRITY_NONE = 0
DEF TNS_NETWORK_DATA_INTEGRITY_MD5 = 1
DEF TNS_NETWORK_DATA_INTEGRITY_SHA1 = 3
DEF TNS_NETWORK_DATA_INTEGRITY_SHA512 = 4
DEF TNS_NETWORK_DATA_INTEGRITY_SHA256 = 5
DEF TNS_NETWORK_DATA_INTEGRITY_SHA384 = 6

# network encryption service constants
DEF TNS_NETWORK_ENCRYPTION_NULL = 0
DEF TNS_NETWORK_ENCRYPTION_RC4_BAS = 1
DEF TNS_NETWORK_ENCRYPTION_RC4_56 = 8
DEF TNS_NETWORK_ENCRYPTION_RC4_128 = 10
DEF TNS_NETWORK_ENCRYPTION_RC4_256 = 6
DEF TNS_NETWORK_ENCRYPTION_DES_40 = 3
DEF TNS_NETWORK_ENCRYPTION_DES_56 = 2
DEF TNS_NETWORK_ENCRYPTION_DES_112 = 11
DEF TNS_NETWORK_ENCRYPTION_DES_168 = 12
DEF TNS_NETWORK_ENCRYPTION_DES_128 = 15
DEF TNS_NETWORK_ENCRYPTION_DES_192 = 16
DEF TNS_NETWORK_ENCRYPTION_DES_256 = 17

cdef class NetworkService:

    cdef uint16_t get_data_size(self):
        return TNS_NETWORK_HEADER_SIZE

    cdef int write_data(self, WriteBuffer buf) except -1:
        raise NotImplementedError()

    cdef int write_header(self, WriteBuffer buf, uint16_t service_num,
                          uint16_t num_sub_packets) except -1:
        buf.write_uint16(service_num)
        buf.write_uint16(num_sub_packets)
        buf.write_uint32(0)

    cdef int write_version(self, WriteBuffer buf) except -1:
        buf.write_uint16(4)             # length
        buf.write_uint16(TNS_NETWORK_TYPE_VERSION)
        buf.write_uint32(TNS_NETWORK_VERSION)


cdef class AuthenticationService(NetworkService):

    cdef uint16_t get_data_size(self):
        return TNS_NETWORK_SERVICE_HEADER_SIZE + 8 + 6 + 6

    cdef int write_data(self, WriteBuffer buf) except -1:
        self.write_header(buf, TNS_NETWORK_SERVICE_AUTH, num_sub_packets=3)
        self.write_version(buf)

        # write auth type
        buf.write_uint16(2)             # length
        buf.write_uint16(TNS_NETWORK_TYPE_UB2)
        buf.write_uint16(TNS_NETWORK_AUTH_TYPE_CLIENT_SERVER)

        # write status
        buf.write_uint16(2)             # length
        buf.write_uint16(TNS_NETWORK_TYPE_STATUS)
        buf.write_uint16(TNS_NETWORK_AUTH_STATUS_NOT_REQUIRED)


cdef class DataIntegrityService(NetworkService):

    cdef uint16_t get_data_size(self):
        return TNS_NETWORK_SERVICE_HEADER_SIZE + 8 + 10

    cdef int write_data(self, WriteBuffer buf) except -1:
        self.write_header(buf, TNS_NETWORK_SERVICE_DATA_INTEGRITY,
                          num_sub_packets=2)
        self.write_version(buf)

        # write options
        buf.write_uint16(6)             # length
        buf.write_uint16(TNS_NETWORK_TYPE_RAW)
        buf.write_uint8(TNS_NETWORK_DATA_INTEGRITY_NONE)
        buf.write_uint8(TNS_NETWORK_DATA_INTEGRITY_MD5)
        buf.write_uint8(TNS_NETWORK_DATA_INTEGRITY_SHA1)
        buf.write_uint8(TNS_NETWORK_DATA_INTEGRITY_SHA512)
        buf.write_uint8(TNS_NETWORK_DATA_INTEGRITY_SHA256)
        buf.write_uint8(TNS_NETWORK_DATA_INTEGRITY_SHA384)


cdef class EncryptionService(NetworkService):

    cdef uint16_t get_data_size(self):
        return TNS_NETWORK_SERVICE_HEADER_SIZE + 8 + 16

    cdef int write_data(self, WriteBuffer buf) except -1:
        self.write_header(buf, TNS_NETWORK_SERVICE_ENCRYPTION,
                          num_sub_packets=2)
        self.write_version(buf)

        # write options
        buf.write_uint16(12)            # length
        buf.write_uint16(TNS_NETWORK_TYPE_RAW)
        buf.write_uint8(TNS_NETWORK_ENCRYPTION_NULL)
        buf.write_uint8(TNS_NETWORK_ENCRYPTION_RC4_BAS)
        buf.write_uint8(TNS_NETWORK_ENCRYPTION_RC4_56)
        buf.write_uint8(TNS_NETWORK_ENCRYPTION_RC4_128)
        buf.write_uint8(TNS_NETWORK_ENCRYPTION_RC4_256)
        buf.write_uint8(TNS_NETWORK_ENCRYPTION_DES_40)
        buf.write_uint8(TNS_NETWORK_ENCRYPTION_DES_56)
        buf.write_uint8(TNS_NETWORK_ENCRYPTION_DES_112)
        buf.write_uint8(TNS_NETWORK_ENCRYPTION_DES_168)
        buf.write_uint8(TNS_NETWORK_ENCRYPTION_DES_128)
        buf.write_uint8(TNS_NETWORK_ENCRYPTION_DES_192)
        buf.write_uint8(TNS_NETWORK_ENCRYPTION_DES_256)


cdef class SupervisorService(NetworkService):

    cdef uint16_t get_data_size(self):
        return TNS_NETWORK_SERVICE_HEADER_SIZE + 8 + 12 + 22

    cdef int write_data(self, WriteBuffer buf) except -1:
        self.write_header(buf, TNS_NETWORK_SERVICE_SUPERVISOR,
                          num_sub_packets=3)
        self.write_version(buf)

        # write CID
        buf.write_uint16(8)             # length
        buf.write_uint16(TNS_NETWORK_TYPE_RAW)
        buf.write_uint64(TNS_NETWORK_SUPERVISOR_CID)

        # write supervised services array
        buf.write_uint16(18)            # length
        buf.write_uint16(TNS_NETWORK_TYPE_RAW)
        buf.write_uint32(TNS_NETWORK_MAGIC)
        buf.write_uint16(TNS_NETWORK_TYPE_UB2)
        buf.write_uint32(4)             # length of array
        buf.write_uint16(TNS_NETWORK_SERVICE_SUPERVISOR)
        buf.write_uint16(TNS_NETWORK_SERVICE_AUTH)
        buf.write_uint16(TNS_NETWORK_SERVICE_ENCRYPTION)
        buf.write_uint16(TNS_NETWORK_SERVICE_DATA_INTEGRITY)


cdef list TNS_NETWORK_SERVICES = [
    SupervisorService(),
    AuthenticationService(),
    EncryptionService(),
    DataIntegrityService()
]
