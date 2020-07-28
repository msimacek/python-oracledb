#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t

cdef extern from "odpi/embed/dpi.c":

    # constants
    unsigned int DPI_MAJOR_VERSION
    unsigned int DPI_MINOR_VERSION

    # opaque handles
    ctypedef struct dpiConn:
        pass

    ctypedef struct dpiContext:
        pass

    ctypedef struct dpiLob:
        pass

    ctypedef struct dpiObject:
        pass

    ctypedef struct dpiPool:
        pass

    ctypedef struct dpiRowid:
        pass

    ctypedef struct dpiStmt:
        pass

    # complex native data types
    ctypedef struct dpiBytes:
        char *ptr
        uint32_t length
        const char *encoding

    ctypedef struct dpiIntervalDS:
        int32_t days
        int32_t hours
        int32_t minutes
        int32_t seconds
        int32_t fseconds

    ctypedef struct dpiIntervalYM:
        int32_t years
        int32_t months

    ctypedef struct dpiTimestamp:
        int16_t year
        uint8_t month
        uint8_t day
        uint8_t hour
        uint8_t minute
        uint8_t second
        uint32_t fsecond
        int8_t tzHourOffset
        int8_t tzMinuteOffset

    # public structures
    ctypedef struct dpiAppContext:
        const char *namespaceName
        uint32_t namespaceNameLength
        const char *name
        uint32_t nameLength
        const char *value
        uint32_t valueLength

    ctypedef struct dpiCommonCreateParams:
        uint32_t createMode
        const char *encoding
        const char *nencoding
        const char *edition
        uint32_t editionLength
        const char *driverName
        uint32_t driverNameLength

    ctypedef struct dpiConnCreateParams:
        uint32_t authMode
        const char *connectionClass
        uint32_t connectionClassLength
        uint32_t purity
        const char *newPassword
        uint32_t newPasswordLength
        dpiAppContext *appContext
        uint32_t numAppContext
        int externalAuth
        void *externalHandle
        dpiPool *pool
        const char *tag
        uint32_t tagLength
        int matchAnyTag
        const char *outTag
        uint32_t outTagLength
        int outTagFound
        dpiShardingKeyColumn *shardingKeyColumns
        uint8_t numShardingKeyColumns
        dpiShardingKeyColumn *superShardingKeyColumns
        uint8_t numSuperShardingKeyColumns
        int outNewSession

    ctypedef struct dpiContextCreateParams:
        const char *defaultDriverName
        const char *defaultEncoding
        const char *loadErrorUrl
        const char *oracleClientLibDir
        const char *oracleClientConfigDir

    ctypedef union dpiDataBuffer:
        int asBoolean
        uint8_t asUint8
        uint16_t asUint16
        uint32_t asUint32
        int64_t asInt64
        uint64_t asUint64
        float asFloat
        double asDouble
        char *asString
        void *asRaw
        dpiBytes asBytes
        dpiTimestamp asTimestamp
        dpiIntervalDS asIntervalDS
        dpiIntervalYM asIntervalYM
        dpiLob *asLOB
        dpiObject *asObject
        dpiStmt *asStmt
        dpiRowid *asRowid

    ctypedef struct dpiErrorInfo:
        int32_t code
        uint16_t offset16
        const char *message
        uint32_t messageLength
        const char *encoding
        const char *fnName
        const char *action
        const char *sqlState
        int isRecoverable
        int isWarning
        uint32_t offset

    ctypedef struct dpiShardingKeyColumn:
        uint32_t oracleTypeNum
        uint32_t nativeTypeNum
        dpiDataBuffer value


    # functions
    int dpiConn_create(const dpiContext *context, const char *userName,
            uint32_t userNameLength, const char *password,
            uint32_t passwordLength, const char *connectString,
            uint32_t connectStringLength,
            const dpiCommonCreateParams *commonParams,
            dpiConnCreateParams *createParams, dpiConn **conn) nogil

    int dpiContext_createWithParams(unsigned int majorVersion,
            unsigned int minorVersion, dpiContextCreateParams *params,
            dpiContext **context, dpiErrorInfo *errorInfo) nogil

    void dpiContext_getError(const dpiContext *context,
            dpiErrorInfo *errorInfo) nogil

    int dpiContext_initCommonCreateParams(const dpiContext *context,
            dpiCommonCreateParams *params) nogil

    int dpiContext_initConnCreateParams(const dpiContext *context,
            dpiConnCreateParams *params) nogil
