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

    cdef BaseSodaCollection _create_collection(self, str name, str metadata,
                                               bint map_mode):
        raise NotImplementedError()

    cdef BaseSodaDoc _create_document(self, bytes content, str key,
                                      str media_type):
        raise NotImplementedError()

    cdef object _get_collection_names(self, str start_name, uint32_t limit):
        raise NotImplementedError()

    cdef BaseSodaCollection _open_collection(self, str name):
        raise NotImplementedError()


cdef class SodaCollection(BaseSodaCollection):
    cdef:
        dpiSodaColl* _handle

    cdef int _create_index(self, str spec) except -1:
        raise NotImplementedError()

    cdef int _drop(self) except -1:
        raise NotImplementedError()

    cdef int _drop_index(self, str name, bint force) except -1:
        raise NotImplementedError()

    cdef BaseSodaDoc _get_data_guide(self):
        raise NotImplementedError()

    cdef object _get_metadata(self):
        raise NotImplementedError()

    cdef int _insert_many(self, list documents) except -1:
        raise NotImplementedError()

    cdef object _insert_many_and_get(self, list documents):
        raise NotImplementedError()

    cdef int _insert_one(self, BaseSodaDoc doc) except -1:
        raise NotImplementedError()

    cdef BaseSodaDoc _insert_one_and_get(self, BaseSodaDoc doc):
        raise NotImplementedError()

    cdef int _save(self, BaseSodaDoc doc) except -1:
        raise NotImplementedError()

    cdef BaseSodaDoc _save_and_get(self, BaseSodaDoc doc):
        raise NotImplementedError()

    cdef int _truncate(self) except -1:
        raise NotImplementedError()


cdef class SodaDoc(BaseSodaDoc):
    cdef:
        dpiSodaDoc* _handle

    cdef object _get_content(self):
        raise NotImplementedError()

    cdef object _get_created_on(self):
        raise NotImplementedError()

    cdef object _get_key(self):
        raise NotImplementedError()

    cdef object _get_last_modified(self):
        raise NotImplementedError()

    cdef object _get_media_type(self):
        raise NotImplementedError()

    cdef object _get_version(self):
        raise NotImplementedError()


cdef class SodaDocCursor(BaseSodaDocCursor):
    cdef:
        dpiSodaDocCursor* _handle

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

    cdef int _replace_one(self, BaseSodaDoc doc, bint* replaced) except -1:
        raise NotImplementedError()

    cdef BaseSodaDoc _replace_one_and_get(self, BaseSodaDoc doc):
        raise NotImplementedError()
