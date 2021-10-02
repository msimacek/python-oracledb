#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class Capabilities:
    cdef:
        uint16_t protocol_version
        uint8_t ttc_field_version
        bytearray compile_caps
        bytearray runtime_caps
        bint supports_oob

    def __init__(self):
        self._init_compile_caps()
        self._init_runtime_caps()

    cdef void _adjust_for_protocol(self, uint16_t protocol_version,
                                   uint16_t protocol_options):
        self.protocol_version = protocol_version
        self.supports_oob = protocol_options & TNS_CAN_RECV_ATTENTION

    @cython.boundscheck(False)
    cdef void _adjust_for_server_compile_caps(self, bytearray server_caps):
        if server_caps[TNS_CCAP_FIELD_VERSION] < self.ttc_field_version:
            self.ttc_field_version = server_caps[TNS_CCAP_FIELD_VERSION]
            self.compile_caps[TNS_CCAP_FIELD_VERSION] = self.ttc_field_version

    @cython.boundscheck(False)
    cdef void _adjust_for_server_runtime_caps(self, bytearray server_caps):
        pass

    @cython.boundscheck(False)
    cdef void _init_compile_caps(self):
        self.ttc_field_version = TNS_CCAP_FIELD_VERSION_MAX
        self.compile_caps = bytearray(TNS_CCAP_MAX)
        self.compile_caps[TNS_CCAP_SQL_VERSION] = TNS_CCAP_SQL_VERSION_MAX
        self.compile_caps[TNS_CCAP_LOGON_TYPES] = \
                TNS_CCAP_O5LOGON | TNS_CCAP_O5LOGON_NP | \
                TNS_CCAP_O7LOGON | TNS_CCAP_O8LOGON_LONG_IDENTIFIER
        self.compile_caps[TNS_CCAP_FIELD_VERSION] = self.ttc_field_version
        self.compile_caps[TNS_CCAP_SERVER_DEFINE_CONV] = 1
        self.compile_caps[TNS_CCAP_TTC1] = \
                TNS_CCAP_FAST_BVEC | TNS_CCAP_END_OF_CALL_STATUS | \
                TNS_CCAP_IND_RCD
        self.compile_caps[TNS_CCAP_OCI1] = \
                TNS_CCAP_FAST_SESSION_PROPAGATE | TNS_CCAP_APP_CTX_PIGGYBACK
        self.compile_caps[TNS_CCAP_TDS_VERSION] = TNS_CCAP_TDS_VERSION_MAX
        self.compile_caps[TNS_CCAP_RPC_VERSION] = TNS_CCAP_RPC_VERSION_MAX
        self.compile_caps[TNS_CCAP_RPC_SIG] = TNS_CCAP_RPC_SIG_VALUE
        self.compile_caps[TNS_CCAP_DBF_VERSION] = TNS_CCAP_DBF_VERSION_MAX
        self.compile_caps[TNS_CCAP_LOB] = TNS_CCAP_LOB_UB8_SIZE | \
                TNS_CCAP_LOB_ENCS
        self.compile_caps[TNS_CCAP_UB2_DTY] = 1
        self.compile_caps[TNS_CCAP_TTC3] = TNS_CCAP_IMPLICIT_RESULTS | \
                TNS_CCAP_BIG_CHUNK_CLR | TNS_CCAP_KEEP_OUT_ORDER
        self.compile_caps[TNS_CCAP_TTC2] = TNS_CCAP_ZLNP
        self.compile_caps[TNS_CCAP_OCI2] = TNS_CCAP_DRCP
        self.compile_caps[TNS_CCAP_CLIENT_FN] = TNS_CCAP_CLIENT_FN_MAX
        self.compile_caps[TNS_CCAP_TTC4] = TNS_CCAP_INBAND_NOTIFICATION

    @cython.boundscheck(False)
    cdef void _init_runtime_caps(self):
        self.runtime_caps = bytearray(TNS_RCAP_MAX)
        self.runtime_caps[TNS_RCAP_COMPAT] = TNS_RCAP_COMPAT_81
        self.runtime_caps[TNS_RCAP_TTC] = TNS_RCAP_TTC_ZERO_COPY | \
                TNS_RCAP_TTC_32K
