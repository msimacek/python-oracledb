#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseSodaDatabase:

    def __repr__(self):
        return f"<oracledb.SodaDatabase on {self._connection!r}"

    cdef BaseSodaCollection _create_collection(self, str name, str metadata,
                                               bint map_mode):
        """
        Internal method for creating a collection.
        """
        raise NotImplementedError()

    cdef BaseSodaDoc _create_document(self, bytes content, str key,
                                      str media_type):
        """
        Internal method for creating a document.
        """
        raise NotImplementedError()

    cdef object _get_collection_names(self, str start_name, uint32_t limit):
        """
        Internal method for getting the list of collection names.
        """
        raise NotImplementedError()

    cdef BaseSodaCollection _open_collection(self, str name):
        """
        Internal method for opening a collection.
        """
        raise NotImplementedError()

    def createCollection(self, name, metadata=None, mapMode=False):
        """
        Create a SODA collection with the given name and return a new SODA
        collection.
        """
        if metadata is not None and not isinstance(metadata, str):
            metadata = json.dumps(metadata)
        return self._create_collection(name, metadata, mapMode)

    def createDocument(self, content, key=None, mediaType="application/json"):
        """
        Create a SODA document with the given content and return it.
        """
        cdef bytes content_bytes
        if isinstance(content, str):
            content_bytes = content.encode()
        elif isinstance(content, bytes):
            content_bytes = content
        else:
            content_bytes = json.dumps(content).encode()
        return self._create_document(content_bytes, key, mediaType)

    def getCollectionNames(self, startName=None, limit=0):
        """
        Return a list of the names of collections found in the database.
        """
        return self._get_collection_names(startName, limit)

    def openCollection(self, name):
        """
        Open an existing collection with the given name and return it.
        """
        return self._open_collection(name)


cdef class BaseSodaCollection:

    cdef int _create_index(self, str spec) except -1:
        """
        Internal method for creating an index on a collection.
        """
        raise NotImplementedError()

    cdef int _drop(self, bint* is_dropped) except -1:
        """
        Internal method for dropping a collection.
        """
        raise NotImplementedError()

    cdef int _drop_index(self, str name, bint force) except -1:
        """
        Internal method for dropping an index on a collection.
        """
        raise NotImplementedError()

    cdef BaseSodaDoc _get_data_guide(self):
        """
        Internal method for getting the data guide for a collection.
        """
        raise NotImplementedError()

    cdef object _get_metadata(self):
        """
        Internal method for getting the metadata for a collection.
        """
        raise NotImplementedError()

    cdef object _insert_many(self, list documents, bint return_docs):
        """
        Internal method for inserting many documents into a collection at once.
        """
        raise NotImplementedError()

    cdef object _insert_one(self, BaseSodaDoc doc, bint return_doc):
        """
        Internal method for inserting a single document into a collection.
        """
        raise NotImplementedError()

    cdef object _save(self, BaseSodaDoc doc, bint return_doc):
        """
        Internal method for saving a document into the collection.
        """
        raise NotImplementedError()

    cdef int _truncate(self) except -1:
        """
        Internal method for truncating the collection (removing all documents
        from it).
        """
        raise NotImplementedError()

    def createIndex(self, spec):
        """
        Create an index on a SODA collection.
        """
        self._create_index(spec)

    def drop(self):
        """
        Drop the collection from the database.
        """
        cdef bint is_dropped
        self._drop(&is_dropped)
        return is_dropped

    def dropIndex(self, name, force=False):
        self._drop_index(name, force)

    def getDataGuide(self):
        return self._get_data_guide()

    def insertMany(self, docs):
        self._insert_many(docs, return_docs=False)

    def insertManyAndGet(self, docs):
        return self._insert_many(docs, return_docs=True)


cdef class BaseSodaDoc:

    cdef object _get_content(self, const char **encoding):
        """
        Internal method for returning the content of the document.
        """
        raise NotImplementedError()

    cdef object _get_created_on(self):
        """
        Internal method for getting the date the document was created.
        """
        raise NotImplementedError()

    cdef object _get_key(self):
        """
        Internal method for getting the key of the document.
        """
        raise NotImplementedError()

    cdef object _get_last_modified(self):
        """
        Internal method for getting the date the document was last modified.
        """
        raise NotImplementedError()

    cdef object _get_media_type(self):
        """
        Internal method for getting the media type of the document.
        """
        raise NotImplementedError()

    cdef object _get_version(self):
        """
        Internal method for getting the version of the document.
        """
        raise NotImplementedError()

    @property
    def createdOn(self):
        return self._get_created_on()

    def getContent(self):
        return json.loads(self.getContentAsString())

    def getContentAsBytes(self):
        cdef const char *encoding_ptr = NULL
        return self._get_content(&encoding_ptr)

    def getContentAsString(self):
        cdef:
            const char *encoding_ptr = NULL
            str encoding = "UTF-8"
        content = self._get_content(&encoding_ptr)
        if encoding_ptr != NULL:
            encoding = encoding_ptr.decode()
        return content.decode(encoding)

    @property
    def key(self):
        return self._get_key()

    @property
    def lastModified(self):
        return self._get_last_modified()

    @property
    def mediaType(self):
        return self._get_media_type()

    @property
    def version(self):
        return self._get_version()


cdef class BaseSodaDocCursor:

    cdef int _close(self) except -1:
        """
        Internal method for closing the cursor.
        """
        raise NotImplementedError()


cdef class BaseSodaOperation:

    cdef int _count(self, uint64_t* count) except -1:
        """
        Internal method for getting the count of documents matching the
        criteria.
        """
        raise NotImplementedError()

    cdef BaseSodaDocCursor _get_cursor(self):
        """
        Internal method for getting a cursor which will return the documents
        matching the criteria.
        """
        raise NotImplementedError()

    cdef object _get_documents(self):
        """
        Internal method for getting the documents matching the criteria.
        """
        raise NotImplementedError()

    cdef BaseSodaDoc _get_one(self):
        """
        Internal method for getting a document matching the criteria.
        """
        raise NotImplementedError()

    cdef object _replace_one(self, BaseSodaDoc doc, bint return_doc,
                             bint* replaced):
        """
        Internal method for replacing the document matching the criteria with
        the supplied coument.
        """
        raise NotImplementedError()
