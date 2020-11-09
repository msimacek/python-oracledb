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

    cdef BaseSodaOperation _create_operation(self):
        """
        Internal method for creating a SODA operation.
        """
        raise NotImplementedError()

    cdef int _drop(self, bint* is_dropped) except -1:
        """
        Internal method for dropping a collection.
        """
        raise NotImplementedError()

    cdef int _drop_index(self, str name, bint force,
                         bint* is_dropped) except -1:
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

    cdef BaseSodaDoc _process_doc_arg(self, object doc_arg):
        """
        Internal method for processing a SODA document arg. The argument must
        be either an actual SODA document already or will be transformed into
        one.
        """
        if isinstance(doc_arg, BaseSodaDoc):
            return doc_arg
        return self._db.createDocument(doc_arg)

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
        if isinstance(spec, dict):
            spec = json.dumps(spec)
        self._create_index(spec)

    def drop(self):
        """
        Drop the collection from the database.
        """
        cdef bint is_dropped
        self._drop(&is_dropped)
        return is_dropped

    def dropIndex(self, name, force=False):
        cdef bint is_dropped
        self._drop_index(name, force, &is_dropped)
        return is_dropped

    def find(self):
        cdef BaseSodaOperation op
        op = self._create_operation()
        op._collection = self
        return op

    def getDataGuide(self):
        return self._get_data_guide()

    def insertMany(self, docs):
        actual_docs = [self._process_doc_arg(d) for d in docs]
        self._insert_many(actual_docs, return_docs=False)

    def insertManyAndGet(self, docs):
        actual_docs = [self._process_doc_arg(d) for d in docs]
        return self._insert_many(actual_docs, return_docs=True)

    def insertOne(self, doc):
        self._insert_one(self._process_doc_arg(doc), return_doc=False)

    def insertOneAndGet(self, doc):
        return self._insert_one(self._process_doc_arg(doc), return_doc=True)

    @property
    def metadata(self):
        return json.loads(self._get_metadata())

    def save(self, doc):
        self._save(self._process_doc_arg(doc), return_doc=False)

    def saveAndGet(self, doc):
        return self._save(self._process_doc_arg(doc), return_doc=True)

    def truncate(self):
        self._truncate()


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

    def __iter__(self):
        return self

    def __next__(self):
        doc = self._get_next_doc()
        if doc is not None:
            return doc
        raise StopIteration

    cdef int _close(self) except -1:
        """
        Internal method for closing the cursor.
        """
        raise NotImplementedError()

    cdef object _get_next_doc(self):
        """
        Internal method for getting the next document from the cursor.
        """
        raise NotImplementedError()

    def close(self):
        """
        Close the document cursor.
        """
        self._close()


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

    cdef BaseSodaDoc _get_one(self):
        """
        Internal method for getting a document matching the criteria.
        """
        raise NotImplementedError()

    cdef int _remove(self, uint64_t* count) except -1:
        """
        Internal method for removing all of the documents matching the
        criteria.
        """
        raise NotImplementedError()

    cdef object _replace_one(self, BaseSodaDoc doc, bint return_doc,
                             bint* replaced):
        """
        Internal method for replacing the document matching the criteria with
        the supplied coument.
        """
        raise NotImplementedError()

    def count(self):
        """
        Return a count of the number of documents matching the criteria.
        """
        cdef uint64_t count
        self._count(&count)
        return count

    def fetchArraySize(self, value):
        """
        Specify the number of documents that will be fetched internally.
        """
        self._fetch_array_size = value
        return self

    def filter(self, value):
        """
        Set a filter specification for complex document queries.
        """
        if isinstance(value, dict):
            self._filter = json.dumps(value)
        else:
            self._filter = value
        return self

    def getCursor(self):
        """
        Return a cursor which will return the documents matching the criteria.
        """
        return self._get_cursor()

    def getDocuments(self):
        """
        Return a list of documents which match the criteria.
        """
        return [d for d in self.getCursor()]

    def getOne(self):
        """
        Return a document matching the criteria.
        """
        return self._get_one()

    def key(self, value):
        """
        Specifies that the document with the given key should be returned.
        """
        self._keys = None
        self._key = value
        return self

    def keys(self, value):
        """
        Specifies that the documents with the matching keys should be returned.
        """
        self._key = None
        self._keys = value
        return self

    def limit(self, value):
        """
        Specifies the maximum number of documents that should be returned.
        """
        self._limit = value
        return self

    def remove(self):
        """
        Remove all of the documents matching the criteria and return the number
        of documents that were removed.
        """
        cdef uint64_t count
        self._remove(&count)
        return count

    def replaceOne(self, doc):
        """
        Replace a single document in the collection matching the criteria with
        the specified document.
        """
        cdef bint replaced
        self._replace_one(self._collection._process_doc_arg(doc),
                          return_doc=False, replaced=&replaced)
        return replaced

    def replaceOneAndGet(self, doc):
        """
        Replace a single document in the collection matching the criteria with
        the specified document and return the modified document.
        """
        cdef bint replaced
        return self._replace_one(self._collection._process_doc_arg(doc),
                                 return_doc=True, replaced=&replaced)

    def skip(self, value):
        """
        Specify how many documents the match the criteria should be skipped.
        """
        self._skip = value
        return self

    def version(self, value):
        """
        Specify that documents with the specified version should be returned.
        """
        self._version = value
        return self
