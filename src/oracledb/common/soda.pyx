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


cdef class BaseSodaCollection:

    cdef int _create_index(self, str spec) except -1:
        """
        Internal method for creating an index on a collection.
        """
        raise NotImplementedError()

    cdef int _drop(self) except -1:
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

    cdef int _insert_many(self, list documents) except -1:
        """
        Internal method for inserting many documents into a collection at once.
        """
        raise NotImplementedError()

    cdef object _insert_many_and_get(self, list documents):
        """
        Internal method for inserting many documents into a collection at once
        and returning a list of the documents inserted.
        """
        raise NotImplementedError()

    cdef int _insert_one(self, BaseSodaDoc doc) except -1:
        """
        Internal method for inserting a single document into a collection.
        """
        raise NotImplementedError()

    cdef BaseSodaDoc _insert_one_and_get(self, BaseSodaDoc doc):
        """
        Internal method for inserting a single document into a collection and
        returning the document thus inserted.
        """
        raise NotImplementedError()

    cdef int _save(self, BaseSodaDoc doc) except -1:
        """
        Internal method for saving a document into the collection.
        """
        raise NotImplementedError()

    cdef BaseSodaDoc _save_and_get(self, BaseSodaDoc doc):
        """
        Internal method for saving a document into the collection and returning
        the modified document.
        """
        raise NotImplementedError()

    cdef int _truncate(self) except -1:
        """
        Internal method for truncating the collection (removing all documents
        from it).
        """
        raise NotImplementedError()


cdef class BaseSodaDoc:

    cdef object _get_content(self):
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

    cdef int _replace_one(self, BaseSodaDoc doc, bint* replaced) except -1:
        """
        Internal method for replacing the document matching the criteria with
        the supplied coument.
        """
        raise NotImplementedError()

    cdef BaseSodaDoc _replace_one_and_get(self, BaseSodaDoc doc):
        """
        Internal method for replacing the document matching the criteria with
        the supplied coument and returning the updated document.
        """
        raise NotImplementedError()
