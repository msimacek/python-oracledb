#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from libc.stdint cimport int8_t, int16_t, int32_t, int64_t
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t

cdef extern from "odpi/embed/dpi.c":

    # version constants
    unsigned int DPI_MAJOR_VERSION
    unsigned int DPI_MINOR_VERSION

    # success/failure constants
    int DPI_SUCCESS
    int DPI_FAILURE

    # defaults
    uint32_t DPI_DEFAULT_PREFETCH_ROWS

    # execution modes
    uint32_t DPI_MODE_EXEC_ARRAY_DML_ROWCOUNTS
    uint32_t DPI_MODE_EXEC_BATCH_ERRORS
    uint32_t DPI_MODE_EXEC_COMMIT_ON_SUCCESS
    uint32_t DPI_MODE_EXEC_DEFAULT
    uint32_t DPI_MODE_EXEC_DESCRIBE_ONLY
    uint32_t DPI_MODE_EXEC_PARSE_ONLY

    # connection/pool creation modes
    uint32_t DPI_MODE_CREATE_DEFAULT
    uint32_t DPI_MODE_CREATE_THREADED
    uint32_t DPI_MODE_CREATE_EVENTS

    # connection close modes
    uint32_t DPI_MODE_CONN_CLOSE_DEFAULT
    uint32_t DPI_MODE_CONN_CLOSE_DROP
    uint32_t DPI_MODE_CONN_CLOSE_RETAG

    # native types
    uint32_t DPI_NATIVE_TYPE_INT64
    uint32_t DPI_NATIVE_TYPE_FLOAT
    uint32_t DPI_NATIVE_TYPE_DOUBLE
    uint32_t DPI_NATIVE_TYPE_BYTES
    uint32_t DPI_NATIVE_TYPE_TIMESTAMP
    uint32_t DPI_NATIVE_TYPE_INTERVAL_DS
    uint32_t DPI_NATIVE_TYPE_LOB
    uint32_t DPI_NATIVE_TYPE_OBJECT
    uint32_t DPI_NATIVE_TYPE_STMT
    uint32_t DPI_NATIVE_TYPE_BOOLEAN
    uint32_t DPI_NATIVE_TYPE_ROWID

    # Oracle types
    uint32_t DPI_ORACLE_TYPE_VARCHAR
    uint32_t DPI_ORACLE_TYPE_NVARCHAR
    uint32_t DPI_ORACLE_TYPE_CHAR
    uint32_t DPI_ORACLE_TYPE_NCHAR
    uint32_t DPI_ORACLE_TYPE_ROWID
    uint32_t DPI_ORACLE_TYPE_RAW
    uint32_t DPI_ORACLE_TYPE_NATIVE_FLOAT
    uint32_t DPI_ORACLE_TYPE_NATIVE_DOUBLE
    uint32_t DPI_ORACLE_TYPE_NATIVE_INT
    uint32_t DPI_ORACLE_TYPE_NUMBER
    uint32_t DPI_ORACLE_TYPE_DATE
    uint32_t DPI_ORACLE_TYPE_TIMESTAMP
    uint32_t DPI_ORACLE_TYPE_TIMESTAMP_TZ
    uint32_t DPI_ORACLE_TYPE_TIMESTAMP_LTZ
    uint32_t DPI_ORACLE_TYPE_INTERVAL_DS
    uint32_t DPI_ORACLE_TYPE_CLOB
    uint32_t DPI_ORACLE_TYPE_NCLOB
    uint32_t DPI_ORACLE_TYPE_BLOB
    uint32_t DPI_ORACLE_TYPE_BFILE
    uint32_t DPI_ORACLE_TYPE_STMT
    uint32_t DPI_ORACLE_TYPE_BOOLEAN
    uint32_t DPI_ORACLE_TYPE_OBJECT
    uint32_t DPI_ORACLE_TYPE_LONG_VARCHAR
    uint32_t DPI_ORACLE_TYPE_LONG_RAW

    # opaque handles
    ctypedef struct dpiConn:
        pass

    ctypedef struct dpiContext:
        pass

    ctypedef struct dpiLob:
        pass

    ctypedef struct dpiObject:
        pass

    ctypedef struct dpiObjectAttr:
        pass

    ctypedef struct dpiObjectType:
        pass

    ctypedef struct dpiPool:
        pass

    ctypedef struct dpiRowid:
        pass

    ctypedef struct dpiStmt:
        pass

    ctypedef struct dpiVar:
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

    ctypedef struct dpiData:
        int isNull
        dpiDataBuffer value

    ctypedef struct dpiDataTypeInfo:
        uint32_t oracleTypeNum
        uint32_t defaultNativeTypeNum
        uint16_t ociTypeCode
        uint32_t dbSizeInBytes
        uint32_t clientSizeInBytes
        uint32_t sizeInChars
        int16_t precision
        int8_t scale
        uint8_t fsPrecision
        dpiObjectType *objectType

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

    ctypedef struct dpiObjectAttrInfo:
        const char *name
        uint32_t nameLength
        dpiDataTypeInfo typeInfo

    ctypedef struct dpiObjectTypeInfo:
        const char *schema
        uint32_t schemaLength
        const char *name
        uint32_t nameLength
        int isCollection
        dpiDataTypeInfo elementTypeInfo
        uint16_t numAttributes

    ctypedef struct dpiPoolCreateParams:
        uint32_t minSessions
        uint32_t maxSessions
        uint32_t sessionIncrement
        int pingInterval
        int pingTimeout
        int homogeneous
        int externalAuth
        uint32_t getMode
        const char *outPoolName
        uint32_t outPoolNameLength
        uint32_t timeout
        uint32_t waitTimeout
        uint32_t maxLifetimeSession
        const char *plsqlFixupCallback
        uint32_t plsqlFixupCallbackLength
        uint32_t maxSessionsPerShard

    ctypedef struct dpiQueryInfo:
        const char *name
        uint32_t nameLength
        dpiDataTypeInfo typeInfo
        int nullOk

    ctypedef struct dpiShardingKeyColumn:
        uint32_t oracleTypeNum
        uint32_t nativeTypeNum
        dpiDataBuffer value

    ctypedef struct dpiStmtInfo:
        int isQuery
        int isPLSQL
        int isDDL
        int isDML
        uint16_t statementType
        int isReturning

    ctypedef struct dpiVersionInfo:
        int versionNum
        int releaseNum
        int updateNum
        int portReleaseNum
        int portUpdateNum
        uint32_t fullVersionNum

    # functions
    int dpiConn_beginDistribTrans(dpiConn *conn, long formatId,
            const char *transactionId, uint32_t transactionIdLength,
            const char *branchId, uint32_t branchIdLength) nogil

    int dpiConn_breakExecution(dpiConn *conn) nogil

    int dpiConn_changePassword(dpiConn *conn, const char *userName,
            uint32_t userNameLength, const char *oldPassword,
            uint32_t oldPasswordLength, const char *newPassword,
            uint32_t newPasswordLength) nogil

    int dpiConn_close(dpiConn *conn, uint32_t mode, const char *tag,
            uint32_t tagLength) nogil

    int dpiConn_commit(dpiConn *conn) nogil

    int dpiConn_create(const dpiContext *context, const char *userName,
            uint32_t userNameLength, const char *password,
            uint32_t passwordLength, const char *connectString,
            uint32_t connectStringLength,
            const dpiCommonCreateParams *commonParams,
            dpiConnCreateParams *createParams, dpiConn **conn) nogil

    int dpiConn_getCurrentSchema(dpiConn *conn, const char **value,
            uint32_t *valueLength) nogil

    int dpiConn_getEdition(dpiConn *conn, const char **value,
            uint32_t *valueLength) nogil

    int dpiConn_getExternalName(dpiConn *conn, const char **value,
            uint32_t *valueLength) nogil

    int dpiConn_getHandle(dpiConn *conn, void **handle) nogil

    int dpiConn_getInternalName(dpiConn *conn, const char **value,
            uint32_t *valueLength) nogil

    int dpiConn_getLTXID(dpiConn *conn, const char **value,
            uint32_t *valueLength) nogil

    int dpiConn_getObjectType(dpiConn *conn, const char *name,
            uint32_t nameLength, dpiObjectType **objType) nogil

    int dpiConn_getServerVersion(dpiConn *conn, const char **releaseString,
            uint32_t *releaseStringLength, dpiVersionInfo *versionInfo) nogil

    int dpiConn_getStmtCacheSize(dpiConn *conn, uint32_t *cacheSize) nogil

    int dpiConn_newTempLob(dpiConn *conn, uint32_t lobType, dpiLob **lob) nogil

    int dpiConn_newVar(dpiConn *conn, uint32_t oracleTypeNum,
            uint32_t nativeTypeNum, uint32_t maxArraySize, uint32_t size,
            int sizeIsBytes, int isArray, dpiObjectType *objType, dpiVar **var,
            dpiData **data) nogil

    int dpiConn_ping(dpiConn *conn) nogil

    int dpiConn_prepareDistribTrans(dpiConn *conn, int *commitNeeded) nogil

    int dpiConn_prepareStmt(dpiConn *conn, int scrollable, const char *sql,
            uint32_t sqlLength, const char *tag, uint32_t tagLength,
            dpiStmt **stmt) nogil

    int dpiConn_release(dpiConn *conn) nogil

    int dpiConn_rollback(dpiConn *conn) nogil

    int dpiConn_setAction(dpiConn *conn, const char *value,
            uint32_t valueLength) nogil

    int dpiConn_setClientIdentifier(dpiConn *conn, const char *value,
            uint32_t valueLength) nogil

    int dpiConn_setClientInfo(dpiConn *conn, const char *value,
            uint32_t valueLength) nogil

    int dpiConn_setCurrentSchema(dpiConn *conn, const char *value,
            uint32_t valueLength) nogil

    int dpiConn_setDbOp(dpiConn *conn, const char *value,
            uint32_t valueLength) nogil

    int dpiConn_setExternalName(dpiConn *conn, const char *value,
            uint32_t valueLength) nogil

    int dpiConn_setInternalName(dpiConn *conn, const char *value,
            uint32_t valueLength) nogil

    int dpiConn_setModule(dpiConn *conn, const char *value,
            uint32_t valueLength) nogil

    int dpiConn_setStmtCacheSize(dpiConn *conn, uint32_t cacheSize) nogil

    int dpiContext_createWithParams(unsigned int majorVersion,
            unsigned int minorVersion, dpiContextCreateParams *params,
            dpiContext **context, dpiErrorInfo *errorInfo) nogil

    int dpiContext_getClientVersion(const dpiContext *context,
            dpiVersionInfo *versionInfo) nogil

    void dpiContext_getError(const dpiContext *context,
            dpiErrorInfo *errorInfo) nogil

    int dpiContext_initCommonCreateParams(const dpiContext *context,
            dpiCommonCreateParams *params) nogil

    int dpiContext_initConnCreateParams(const dpiContext *context,
            dpiConnCreateParams *params) nogil

    int dpiContext_initPoolCreateParams(const dpiContext *context,
            dpiPoolCreateParams *params) nogil

    int dpiLob_addRef(dpiLob *lob) nogil

    int dpiLob_closeResource(dpiLob *lob) nogil

    int dpiLob_getBufferSize(dpiLob *lob, uint64_t sizeInChars,
            uint64_t *sizeInBytes) nogil

    int dpiLob_getChunkSize(dpiLob *lob, uint32_t *size) nogil

    int dpiLob_getDirectoryAndFileName(dpiLob *lob,
            const char **directoryAlias, uint32_t *directoryAliasLength,
            const char **fileName, uint32_t *fileNameLength) nogil

    int dpiLob_getFileExists(dpiLob *lob, bint *exists) nogil

    int dpiLob_getIsResourceOpen(dpiLob *lob, bint *isOpen) nogil

    int dpiLob_getSize(dpiLob *lob, uint64_t *size) nogil

    int dpiLob_openResource(dpiLob *lob) nogil

    int dpiLob_readBytes(dpiLob *lob, uint64_t offset, uint64_t amount,
            char *value, uint64_t *valueLength) nogil

    int dpiLob_release(dpiLob *lob) nogil

    int dpiLob_setDirectoryAndFileName(dpiLob *lob,
            const char *directoryAlias, uint32_t directoryAliasLength,
            const char *fileName, uint32_t fileNameLength) nogil

    int dpiLob_setFromBytes(dpiLob *lob, const char *value,
            uint64_t valueLength) nogil

    int dpiLob_trim(dpiLob *lob, uint64_t newSize) nogil

    int dpiLob_writeBytes(dpiLob *lob, uint64_t offset,
            const char *value, uint64_t valueLength) nogil

    int dpiObject_addRef(dpiObject *obj) nogil

    int dpiObject_appendElement(dpiObject *obj, uint32_t nativeTypeNum,
            dpiData *value) nogil

    int dpiObject_copy(dpiObject *obj, dpiObject **copiedObj) nogil

    int dpiObject_deleteElementByIndex(dpiObject *obj, int32_t index) nogil

    int dpiObject_getAttributeValue(dpiObject *obj, dpiObjectAttr *attr,
            uint32_t nativeTypeNum, dpiData *value) nogil

    int dpiObject_getElementExistsByIndex(dpiObject *obj, int32_t index,
            bint *exists) nogil

    int dpiObject_getElementValueByIndex(dpiObject *obj, int32_t index,
            uint32_t nativeTypeNum, dpiData *value) nogil

    int dpiObject_getFirstIndex(dpiObject *obj, int32_t *index,
            bint *exists) nogil

    int dpiObject_getLastIndex(dpiObject *obj, int32_t *index,
            bint *exists) nogil

    int dpiObject_getNextIndex(dpiObject *obj, int32_t index,
            int32_t *nextIndex, bint *exists) nogil

    int dpiObject_getPrevIndex(dpiObject *obj, int32_t index,
            int32_t *prevIndex, bint *exists) nogil

    int dpiObject_getSize(dpiObject *obj, int32_t *size) nogil

    int dpiObject_release(dpiObject *obj) nogil

    int dpiObject_setAttributeValue(dpiObject *obj, dpiObjectAttr *attr,
            uint32_t nativeTypeNum, dpiData *value) nogil

    int dpiObject_setElementValueByIndex(dpiObject *obj, int32_t index,
            uint32_t nativeTypeNum, dpiData *value) nogil

    int dpiObject_trim(dpiObject *obj, uint32_t numToTrim) nogil

    int dpiObjectAttr_getInfo(dpiObjectAttr *attr,
            dpiObjectAttrInfo *info) nogil

    int dpiObjectAttr_release(dpiObjectAttr *attr) nogil

    int dpiObjectType_addRef(dpiObjectType *objType) nogil

    int dpiObjectType_createObject(dpiObjectType *objType,
            dpiObject **obj) nogil

    int dpiObjectType_getAttributes(dpiObjectType *objType,
            uint16_t numAttributes, dpiObjectAttr **attributes) nogil

    int dpiObjectType_getInfo(dpiObjectType *objType,
            dpiObjectTypeInfo *info) nogil

    int dpiObjectType_release(dpiObjectType *objType) nogil

    int dpiPool_create(const dpiContext *context, const char *userName,
            uint32_t userNameLength, const char *password,
            uint32_t passwordLength, const char *connectString,
            uint32_t connectStringLength,
            const dpiCommonCreateParams *commonParams,
            dpiPoolCreateParams *createParams, dpiPool **pool) nogil

    int dpiPool_release(dpiPool *pool) nogil

    int dpiRowid_getStringValue(dpiRowid *rowid, const char **value,
            uint32_t *valueLength)

    int dpiStmt_addRef(dpiStmt *stmt) nogil

    int dpiStmt_bindByName(dpiStmt *stmt, const char *name,
            uint32_t nameLength, dpiVar *var) nogil

    int dpiStmt_bindByPos(dpiStmt *stmt, uint32_t pos, dpiVar *var) nogil

    int dpiStmt_close(dpiStmt *stmt, const char *tag, uint32_t tagLength)

    int dpiStmt_define(dpiStmt *stmt, uint32_t pos, dpiVar *var) nogil

    int dpiStmt_execute(dpiStmt *stmt, uint32_t mode,
            uint32_t *numQueryColumns) nogil

    int dpiStmt_executeMany(dpiStmt *stmt, uint32_t mode,
            uint32_t numIters) nogil

    int dpiStmt_fetchRows(dpiStmt *stmt, uint32_t maxRows,
            uint32_t *bufferRowIndex, uint32_t *numRowsFetched,
            bint *moreRows) nogil

    int dpiStmt_getBatchErrorCount(dpiStmt *stmt, uint32_t *count) nogil

    int dpiStmt_getBatchErrors(dpiStmt *stmt, uint32_t numErrors,
            dpiErrorInfo *errors) nogil

    int dpiStmt_getBindCount(dpiStmt *stmt, uint32_t *count) nogil

    int dpiStmt_getBindNames(dpiStmt *stmt, uint32_t *numBindNames,
            const char **bindNames, uint32_t *bindNameLengths) nogil

    int dpiStmt_getImplicitResult(dpiStmt *stmt,
            dpiStmt **implicitResult) nogil

    int dpiStmt_getNumQueryColumns(dpiStmt *stmt,
            uint32_t *numQueryColumns) nogil

    int dpiStmt_getRowCounts(dpiStmt *stmt, uint32_t *numRowCounts,
            uint64_t **rowCounts) nogil

    int dpiStmt_getInfo(dpiStmt *stmt, dpiStmtInfo *info) nogil

    int dpiStmt_getLastRowid(dpiStmt *stmt, dpiRowid **rowid) nogil

    int dpiStmt_getQueryInfo(dpiStmt *stmt, uint32_t pos,
            dpiQueryInfo *info) nogil

    int dpiStmt_getRowCount(dpiStmt *stmt, uint64_t *count) nogil

    int dpiStmt_release(dpiStmt *stmt) nogil

    int dpiStmt_scroll(dpiStmt *stmt, uint32_t mode, int32_t offset,
            int32_t rowCountOffset) nogil

    int dpiStmt_setFetchArraySize(dpiStmt *stmt, uint32_t arraySize) nogil

    int dpiStmt_setPrefetchRows(dpiStmt *stmt, uint32_t numRows) nogil

    int dpiVar_getNumElementsInArray(dpiVar *var, uint32_t *numElements) nogil

    int dpiVar_getReturnedData(dpiVar *var, uint32_t pos,
            uint32_t *numElements, dpiData **data) nogil

    int dpiVar_getSizeInBytes(dpiVar *var, uint32_t *sizeInBytes) nogil

    int dpiVar_release(dpiVar *var) nogil

    int dpiVar_setNumElementsInArray(dpiVar *var, uint32_t numElements) nogil

    int dpiVar_setFromBytes(dpiVar *var, uint32_t pos, const char *value,
            uint32_t valueLength) nogil

    int dpiVar_setFromLob(dpiVar *var, uint32_t pos, dpiLob *lob) nogil

    int dpiVar_setFromObject(dpiVar *var, uint32_t pos, dpiObject *obj) nogil

    int dpiVar_setFromStmt(dpiVar *var, uint32_t pos, dpiStmt *stmt) nogil
