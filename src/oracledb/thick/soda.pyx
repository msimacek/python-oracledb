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
        cdef:
            StringBuffer buf = StringBuffer()
            uint32_t flags
            int status
        buf.set_value(spec)
        self._get_flags(&flags)
        with nogil:
            status = dpiSodaColl_createIndex(self._handle, buf.ptr, buf.length,
                                             flags)
        if status < 0:
            _raise_from_odpi()

    cdef BaseSodaOperation _create_operation(self):
        return SodaOperation.__new__(SodaOperation)

    cdef int _drop(self, bint* is_dropped) except -1:
        cdef uint32_t flags
        self._get_flags(&flags)
        if dpiSodaColl_drop(self._handle, flags, is_dropped) < 0:
            _raise_from_odpi()

    cdef int _drop_index(self, str name, bint force,
                         bint* is_dropped) except -1:
        cdef:
            StringBuffer buf = StringBuffer()
            uint32_t flags
            int status
        buf.set_value(name)
        self._get_flags(&flags)
        if force:
            flags |= DPI_SODA_FLAGS_INDEX_DROP_FORCE
        with nogil:
            status = dpiSodaColl_dropIndex(self._handle, buf.ptr, buf.length,
                                           flags, is_dropped)
        if status < 0:
            _raise_from_odpi()

    cdef BaseSodaDoc _get_data_guide(self):
        cdef:
            uint32_t flags
            SodaDoc doc
            int status
        self._get_flags(&flags)
        doc = SodaDoc.__new__(SodaDoc)
        doc._db = self._db
        with nogil:
            status = dpiSodaColl_getDataGuide(self._handle, flags,
                                              &doc._handle)
        if status < 0:
            _raise_from_odpi()
        if doc._handle != NULL:
            return doc

    cdef int _get_flags(self, uint32_t* flags) except -1:
        cdef SodaDatabase db = <SodaDatabase> self._db
        db._get_flags(flags)

    cdef object _get_metadata(self):
        cdef:
            uint32_t value_len
            const char* value
        if dpiSodaColl_getMetadata(self._handle, &value, &value_len) < 0:
            _raise_from_odpi()
        return value[:value_len].decode()

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
        cdef:
            dpiSodaDoc **output_handle = NULL
            SodaDoc thick_doc, output_doc
            uint32_t flags
            int status
        thick_doc = <SodaDoc> doc
        if return_doc:
            output_doc = SodaDoc.__new__(SodaDoc)
            output_doc._db = self._db
            output_handle = &output_doc._handle
        self._get_flags(&flags)
        with nogil:
            status = dpiSodaColl_insertOne(self._handle, thick_doc._handle,
                                           flags, output_handle)
        if status < 0:
            _raise_from_odpi()
        if return_doc:
            return output_doc

    cdef object _save(self, BaseSodaDoc doc, bint return_doc):
        raise NotImplementedError()

    cdef int _truncate(self) except -1:
        cdef int status
        with nogil:
            status = dpiSodaColl_truncate(self._handle)
        if status < 0:
            _raise_from_odpi()


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

    cdef object _get_next_doc(self):
        cdef:
            SodaDatabase db = <SodaDatabase> self._db
            uint32_t flags
            SodaDoc doc
            int status
        db._get_flags(&flags)
        doc = SodaDoc.__new__(SodaDoc)
        doc._db = db
        with nogil:
            status = dpiSodaDocCursor_getNext(self._handle, flags,
                                              &doc._handle)
        if status < 0:
            _raise_from_odpi()
        if doc._handle != NULL:
            return doc


cdef class SodaOperation(BaseSodaOperation):
    cdef:
        uint32_t _allocated_keys
        uint32_t* _key_lengths
        char** _key_values
        list _buffers

    def __dealloc__(self):
        self._clear_keys()

    cdef int _add_buf(self, object value, const char **ptr,
                      uint32_t *length) except -1:
        cdef StringBuffer buf = StringBuffer()
        buf.set_value(value)
        self._buffers.append(buf)
        ptr[0] = buf.ptr
        length[0] = buf.length

    cdef void _clear_keys(self):
        if self._key_values != NULL:
            cpython.PyMem_Free(self._key_values)
        if self._key_lengths != NULL:
            cpython.PyMem_Free(self._key_lengths)

    cdef int _count(self, uint64_t* count) except -1:
        cdef:
            SodaCollection collection = <SodaCollection> self._collection
            dpiSodaOperOptions options
            uint32_t flags
            int status
        collection._get_flags(&flags)
        self._get_options(&options)
        with nogil:
            status = dpiSodaColl_getDocCount(collection._handle, &options,
                                             flags, count)
        if status < 0:
            _raise_from_odpi()

    cdef int _get_options(self, dpiSodaOperOptions* options) except -1:
        cdef:
            ssize_t num_bytes
            uint32_t i
        self._buffers = []
        if dpiContext_initSodaOperOptions(driver_context, options) < 0:
            _raise_from_odpi()
        if self._key:
            self._add_buf(self._key, &options.key, &options.keyLength)
        if self._keys:
            options.numKeys = <uint32_t> len(self._keys)
            if options.numKeys > self._allocated_keys:
                self._clear_keys()
                num_bytes = options.numKeys * sizeof(char*)
                self._key_values = <char**> cpython.PyMem_Malloc(num_bytes)
                num_bytes = options.numKeys * sizeof(uint32_t)
                self._key_lengths = <uint32_t*> cpython.PyMem_Malloc(num_bytes)
                self._allocated_keys = options.numKeys
            options.keys = self._key_values
            options.keyLengths = self._key_lengths
            for i in range(options.numKeys):
                self._add_buf(self._keys[i], &self._key_values[i],
                              &self._key_lengths[i])
        if self._version:
            self._add_buf(self._version, &options.version,
                          &options.versionLength)
        if self._filter:
            self._add_buf(self._filter, &options.filter, &options.filterLength)
        options.skip = self._skip
        options.limit = self._limit
        options.fetchArraySize = self._fetch_array_size

    cdef BaseSodaDocCursor _get_cursor(self):
        cdef:
            SodaCollection collection = <SodaCollection> self._collection
            dpiSodaOperOptions options
            SodaDocCursor cursor
            uint32_t flags
            int status
        collection._get_flags(&flags)
        self._get_options(&options)
        cursor = SodaDocCursor.__new__(SodaDocCursor)
        cursor._db = collection._db
        with nogil:
            status = dpiSodaColl_find(collection._handle, &options, flags,
                                      &cursor._handle)
        if status < 0:
            _raise_from_odpi()
        return cursor

    cdef BaseSodaDoc _get_one(self):
        cdef:
            SodaCollection collection = <SodaCollection> self._collection
            dpiSodaOperOptions options
            uint32_t flags
            SodaDoc doc
            int status
        collection._get_flags(&flags)
        self._get_options(&options)
        doc = SodaDoc.__new__(SodaDoc)
        doc._db = collection._db
        with nogil:
            status = dpiSodaColl_findOne(collection._handle, &options, flags,
                                         &doc._handle)
        if status < 0:
            _raise_from_odpi()
        if doc._handle != NULL:
            return doc

    cdef int _remove(self, uint64_t* count) except -1:
        cdef:
            SodaCollection collection = <SodaCollection> self._collection
            dpiSodaOperOptions options
            uint32_t flags
            int status
        collection._get_flags(&flags)
        self._get_options(&options)
        with nogil:
            status = dpiSodaColl_remove(collection._handle, &options, flags,
                                        count)
        if status < 0:
            _raise_from_odpi()

    cdef object _replace_one(self, BaseSodaDoc doc, bint return_doc,
                             bint* replaced):
        cdef:
            SodaCollection collection = <SodaCollection> self._collection
            dpiSodaDoc **output_handle = NULL
            SodaDoc thick_doc, output_doc
            dpiSodaOperOptions options
            uint32_t flags
            int status
        thick_doc = <SodaDoc> doc
        if return_doc:
            output_doc = SodaDoc.__new__(SodaDoc)
            output_doc._db = collection._db
            output_handle = &output_doc._handle
        collection._get_flags(&flags)
        self._get_options(&options)
        with nogil:
            status = dpiSodaColl_replaceOne(collection._handle, &options,
                                            thick_doc._handle, flags, replaced,
                                            output_handle)
        if status < 0:
            _raise_from_odpi()
        if return_doc:
            return output_doc
