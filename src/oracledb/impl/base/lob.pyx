#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

cdef class BaseLobImpl:

    def close(self):
        """
        Internal method for closing a LOB that was opened earlier.
        """
        raise NotImplementedError()

    def file_exists(self):
        """
        Internal method for returning whether the file referenced by a BFILE
        exists.
        """
        raise NotImplementedError()

    def get_chunk_size(self):
        """
        Internal method for returning the chunk size of the LOB.
        """
        raise NotImplementedError()

    def get_file_name(self):
        """
        Internal method for returning a 2-tuple constaining the directory alias
        and file name of a BFILE type LOB.
        """
        raise NotImplementedError()

    def get_is_open(self):
        """
        Internal method for returning whether the LOB is open or not.
        """
        raise NotImplementedError()

    def get_max_amount(self):
        """
        Internal method for returning the maximum amount that can be read.
        """
        raise NotImplementedError()

    def get_size(self):
        """
        Internal method for returning the size of a LOB.
        """
        raise NotImplementedError()

    def open(self):
        """
        Internal method for opening a LOB.
        """
        raise NotImplementedError()

    def read(self, uint64_t offset, uint64_t amount):
        """
        Internal method for reading a portion (or all) of the data in the LOB.
        """
        raise NotImplementedError()

    def set_file_name(self, str dir_alias, str name):
        """
        Internal method for setting the directory alias and file name
        associated with a BFILE LOB.
        """
        raise NotImplementedError()

    def trim(self, uint64_t new_size):
        """
        Internal method for trimming the data in the LOB to the new size
        """
        raise NotImplementedError()

    def write(self, object value, uint64_t offset):
        """
        Internal method for writing data to the LOB object.
        """
        raise NotImplementedError()
