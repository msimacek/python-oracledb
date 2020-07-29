#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

# packet types
cdef uint8_t TNS_PACKET_TYPE_CONNECT = 1
cdef uint8_t TNS_PACKET_TYPE_ACCEPT = 2
cdef uint8_t TNS_PACKET_TYPE_REFUSE = 4
cdef uint8_t TNS_PACKET_TYPE_DATA = 6
cdef uint8_t TNS_PACKET_TYPE_RESEND = 11
cdef uint8_t TNS_PACKET_TYPE_MARKER = 12

# packet data indicators
cdef uint64_t TNS_PACKET_IND_PTR = 0xfffffffffffffffe

# operations
cdef uint16_t TNS_OPERATION_NONE = 0
cdef uint16_t TNS_OPERATION_AUTH = 1
cdef uint16_t TNS_OPERATION_QUERY = 2
cdef uint16_t TNS_OPERATION_ERROR = 3
cdef uint16_t TNS_OPERATION_EXECUTE = 4
cdef uint16_t TNS_OPERATION_COMMIT = 5
cdef uint16_t TNS_OPERATION_ROLLBACK = 6
cdef uint16_t TNS_OPERATION_CLOSE = 7

# flags
cdef uint16_t TNS_FLAGS_NONE = 0
cdef uint16_t TNS_FLAGS_CONNECT = 32

# authentication states
cdef uint16_t TNS_AUTH_STATE_START = 0
cdef uint16_t TNS_AUTH_STATE_RESEND = 1
cdef uint16_t TNS_AUTH_STATE_SERVICES = 2
cdef uint16_t TNS_AUTH_STATE_PROTOCOL = 3
cdef uint16_t TNS_AUTH_STATE_DATA_TYPES = 4
cdef uint16_t TNS_AUTH_STATE_SESSION_KEY = 5
cdef uint16_t TNS_AUTH_STATE_AUTHENTICATION = 6
cdef uint16_t TNS_AUTH_STATE_CONNECTED = 7
cdef uint16_t TNS_AUTH_STATE_FINAL = 8

# charset forms
cdef uint8_t TNS_CS_IMPLICIT = 1
cdef uint8_t TNS_CS_NCHAR = 2

# data types
cdef uint8_t TNS_DATA_TYPE_VARCHAR = 1
cdef uint8_t TNS_DATA_TYPE_NUMBER = 2
cdef uint8_t TNS_DATA_TYPE_RAW = 23
cdef uint8_t TNS_DATA_TYPE_CHAR = 96
cdef uint8_t TNS_DATA_TYPE_NVARCHAR = 101
cdef uint8_t TNS_DATA_TYPE_NCHAR = 196

# fetch message types
cdef uint8_t TNS_MSG_TYPE_ROW_HEADER = 6
cdef uint8_t TNS_MSG_TYPE_ROW_DATA = 7
cdef uint8_t TNS_MSG_TYPE_PARAMETER = 8
cdef uint8_t TNS_MSG_TYPE_BIT_VECTOR = 21
