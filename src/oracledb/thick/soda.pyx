#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# soda.pyx
#   Cython file defining the SODA classes (embedded in driver.pyx).
#------------------------------------------------------------------------------

cdef class SodaDatabase(BaseSodaDatabase):
    cdef:
        dpiSodaDb* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiSodaDb_release(self._handle)

    cdef BaseSodaCollection _create_collection(self, str name, str metadata,
                                               bint map_mode):
        cdef:
            StringBuffer metadata_buf = StringBuffer()
            StringBuffer name_buf = StringBuffer()
            SodaCollection collection
            uint32_t flags
            int status
        name_buf.set_value(name)
        metadata_buf.set_value(metadata)
        self._get_flags(&flags)
        if map_mode:
            flags |= DPI_SODA_FLAGS_CREATE_COLL_MAP
        collection = SodaCollection.__new__(SodaCollection)
        collection._db = self
        with nogil:
            status = dpiSodaDb_createCollection(self._handle, name_buf.ptr,
                                                name_buf.length,
                                                metadata_buf.ptr,
                                                metadata_buf.length, flags,
                                                &collection._handle)
        if status < 0:
            _raise_from_odpi()
        collection._initialize()
        return collection

    cdef BaseSodaDoc _create_document(self, bytes content, str key,
                                      str media_type):
        cdef:
            StringBuffer media_type_buf = StringBuffer()
            StringBuffer content_buf = StringBuffer()
            StringBuffer key_buf = StringBuffer()
            SodaDoc doc
        content_buf.set_value(content)
        key_buf.set_value(key)
        media_type_buf.set_value(media_type)
        doc = SodaDoc.__new__(SodaDoc)
        doc._db = self
        if dpiSodaDb_createDocument(self._handle, key_buf.ptr, key_buf.length,
                                    content_buf.ptr, content_buf.length,
                                    media_type_buf.ptr, media_type_buf.length,
                                    DPI_SODA_FLAGS_DEFAULT, &doc._handle) < 0:
            _raise_from_odpi()
        return doc

    cdef object _get_collection_names(self, str start_name, uint32_t limit):
        cdef:
            StringBuffer start_name_buf = StringBuffer()
            dpiSodaCollNames coll_names
            uint32_t flags, i
            list result
            int status
            str temp
        start_name_buf.set_value(start_name)
        self._get_flags(&flags)
        with nogil:
            status = dpiSodaDb_getCollectionNames(self._handle,
                                                  start_name_buf.ptr,
                                                  start_name_buf.length,
                                                  limit, flags, &coll_names)
        if status < 0:
            _raise_from_odpi()
        try:
            result = cpython.PyList_New(coll_names.numNames)
            for i in range(coll_names.numNames):
                temp = coll_names.names[i][:coll_names.nameLengths[i]].decode()
                cpython.Py_INCREF(temp)
                cpython.PyList_SET_ITEM(result, i, temp)
            return result
        finally:
            if dpiSodaDb_freeCollectionNames(self._handle, &coll_names) < 0:
                _raise_from_odpi()

    cdef int _get_flags(self, uint32_t* flags) except -1:
        self._connection._verify_connected()
        if self._connection.autocommit:
            flags[0] = DPI_SODA_FLAGS_ATOMIC_COMMIT
        else:
            flags[0] = DPI_SODA_FLAGS_DEFAULT

    cdef BaseSodaCollection _open_collection(self, str name):
        cdef:
            StringBuffer name_buf = StringBuffer()
            SodaCollection collection
            uint32_t flags
            int status
        name_buf.set_value(name)
        self._get_flags(&flags)
        collection = SodaCollection.__new__(SodaCollection)
        collection._db = self
        with nogil:
            status = dpiSodaDb_openCollection(self._handle, name_buf.ptr,
                                              name_buf.length, flags,
                                              &collection._handle)
        if status < 0:
            _raise_from_odpi()
        if collection._handle != NULL:
            collection._initialize()
            return collection


cdef class SodaCollection(BaseSodaCollection):
    cdef:
        dpiSodaColl* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiSodaColl_release(self._handle)

    cdef int _create_index(self, str spec) except -1:
        raise NotImplementedError()

    cdef int _drop(self, bint* is_dropped) except -1:
        cdef:
            SodaDatabase db = <SodaDatabase> self._db
            uint32_t flags
        db._get_flags(&flags)
        if dpiSodaColl_drop(self._handle, flags, is_dropped) < 0:
            _raise_from_odpi()

    cdef int _drop_index(self, str name, bint force) except -1:
        raise NotImplementedError()

    cdef BaseSodaDoc _get_data_guide(self):
        raise NotImplementedError()

    cdef object _get_metadata(self):
        raise NotImplementedError()

    cdef int _initialize(self) except -1:
        cdef:
            uint32_t name_len
            const char *name
        if dpiSodaColl_getName(self._handle, &name, &name_len) < 0:
            _raise_from_odpi()
        self.name = name[:name_len].decode()

    cdef object _insert_many(self, list documents, bint return_doc):
        raise NotImplementedError()

    cdef object _insert_one(self, BaseSodaDoc doc, bint return_doc):
        raise NotImplementedError()

    cdef object _save(self, BaseSodaDoc doc, bint return_doc):
        raise NotImplementedError()

    cdef int _truncate(self) except -1:
        raise NotImplementedError()


cdef class SodaDoc(BaseSodaDoc):
    cdef:
        dpiSodaDoc* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiSodaDoc_release(self._handle)

    cdef object _get_content(self, const char **encoding):
        cdef:
            uint32_t content_len
            const char *content
        if dpiSodaDoc_getContent(self._handle, &content, &content_len,
                                 encoding) < 0:
            _raise_from_odpi()
        return content[:content_len]

    cdef object _get_created_on(self):
        cdef:
            uint32_t value_len
            const char *value
        if dpiSodaDoc_getCreatedOn(self._handle, &value, &value_len) < 0:
            _raise_from_odpi()
        if value_len > 0:
            return value[:value_len].decode()

    cdef object _get_key(self):
        cdef:
            uint32_t value_len
            const char *value
        if dpiSodaDoc_getKey(self._handle, &value, &value_len) < 0:
            _raise_from_odpi()
        if value_len > 0:
            return value[:value_len].decode()

    cdef object _get_last_modified(self):
        cdef:
            uint32_t value_len
            const char *value
        if dpiSodaDoc_getLastModified(self._handle, &value, &value_len) < 0:
            _raise_from_odpi()
        if value_len > 0:
            return value[:value_len].decode()

    cdef object _get_media_type(self):
        cdef:
            uint32_t value_len
            const char *value
        if dpiSodaDoc_getMediaType(self._handle, &value, &value_len) < 0:
            _raise_from_odpi()
        if value_len > 0:
            return value[:value_len].decode()

    cdef object _get_version(self):
        cdef:
            uint32_t value_len
            const char *value
        if dpiSodaDoc_getVersion(self._handle, &value, &value_len) < 0:
            _raise_from_odpi()
        if value_len > 0:
            return value[:value_len].decode()


cdef class SodaDocCursor(BaseSodaDocCursor):
    cdef:
        dpiSodaDocCursor* _handle

    def __dealloc__(self):
        if self._handle != NULL:
            dpiSodaDocCursor_release(self._handle)

    cdef int _close(self) except -1:
        raise NotImplementedError()


cdef class SodaOperation(BaseSodaOperation):

    cdef int _count(self, uint64_t* count) except -1:
        raise NotImplementedError()

    cdef BaseSodaDocCursor _get_cursor(self):
        raise NotImplementedError()

    cdef object _get_documents(self):
        raise NotImplementedError()

    cdef BaseSodaDoc _get_one(self):
        raise NotImplementedError()

    cdef object _replace_one(self, BaseSodaDoc doc, bint return_doc,
                             bint* replaced):
        raise NotImplementedError()
