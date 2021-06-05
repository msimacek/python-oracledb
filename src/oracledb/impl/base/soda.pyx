#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseSodaDbImpl:

    def create_collection(self, str name, str metadata, bint map_mode):
        """
        Internal method for creating a collection.
        """
        raise NotImplementedError()

    def create_document(self, bytes content, str key, str media_type):
        """
        Internal method for creating a document.
        """
        raise NotImplementedError()

    def get_collection_names(self, str start_name, uint32_t limit):
        """
        Internal method for getting the list of collection names.
        """
        raise NotImplementedError()

    def open_collection(self, str name):
        """
        Internal method for opening a collection.
        """
        raise NotImplementedError()


cdef class BaseSodaCollImpl:

    def create_index(self, str spec):
        """
        Internal method for creating an index on a collection.
        """
        raise NotImplementedError()

    def drop(self):
        """
        Internal method for dropping a collection.
        """
        raise NotImplementedError()

    def drop_index(self, str name, bint force):
        """
        Internal method for dropping an index on a collection.
        """
        raise NotImplementedError()

    def get_count(self, object op):
        """
        Internal method for getting the count of documents matching the
        criteria.
        """
        raise NotImplementedError()

    def get_cursor(self, object op):
        """
        Internal method for getting a cursor which will return the documents
        matching the criteria.
        """
        raise NotImplementedError()

    def get_data_guide(self):
        """
        Internal method for getting the data guide for a collection.
        """
        raise NotImplementedError()

    def get_metadata(self):
        """
        Internal method for getting the metadata for a collection.
        """
        raise NotImplementedError()

    def get_one(self, object op):
        """
        Internal method for getting a document matching the criteria.
        """
        raise NotImplementedError()

    def insert_many(self, list documents, str hint, bint return_docs):
        """
        Internal method for inserting many documents into a collection at once.
        """
        raise NotImplementedError()

    def insert_one(self, BaseSodaDocImpl doc, str hint, bint return_doc):
        """
        Internal method for inserting a single document into a collection.
        """
        raise NotImplementedError()

    def remove(self, object op):
        """
        Internal method for removing all of the documents matching the
        criteria.
        """
        raise NotImplementedError()

    def replace_one(self, BaseSodaDocImpl doc_impl, bint return_doc):
        """
        Internal method for replacing the document matching the criteria with
        the supplied coument.
        """
        raise NotImplementedError()

    def save(self, BaseSodaDocImpl doc, str hint, bint return_doc):
        """
        Internal method for saving a document into the collection.
        """
        raise NotImplementedError()

    def truncate(self):
        """
        Internal method for truncating the collection (removing all documents
        from it).
        """
        raise NotImplementedError()


cdef class BaseSodaDocImpl:

    def get_content(self):
        """
        Internal method for returning the content of the document.
        """
        raise NotImplementedError()

    def get_created_on(self):
        """
        Internal method for getting the date the document was created.
        """
        raise NotImplementedError()

    def get_key(self):
        """
        Internal method for getting the key of the document.
        """
        raise NotImplementedError()

    def get_last_modified(self):
        """
        Internal method for getting the date the document was last modified.
        """
        raise NotImplementedError()

    def get_media_type(self):
        """
        Internal method for getting the media type of the document.
        """
        raise NotImplementedError()

    def get_version(self):
        """
        Internal method for getting the version of the document.
        """
        raise NotImplementedError()


cdef class BaseSodaDocCursorImpl:

    def close(self):
        """
        Internal method for closing the cursor.
        """
        raise NotImplementedError()

    def get_next_doc(self):
        """
        Internal method for getting the next document from the cursor.
        """
        raise NotImplementedError()
