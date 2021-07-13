#------------------------------------------------------------------------------
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from typing import Union

class LOB:

    def __str__(self):
        return self.read()

    @classmethod
    def _from_impl(cls, impl):
        lob = cls.__new__(cls)
        lob._impl = impl
        return lob

    def close(self) -> None:
        """
        Close the LOB. Call this when writing is completed so that the indexes
        associated with the LOB can be updated -– but only if open() was called
        first.
        """
        self._impl.close()

    def fileexists(self) -> bool:
        """
        Return a boolean indicating if the file referenced by a BFILE type LOB
        exists.
        """
        return self._impl.file_exists()

    def getchunksize(self) -> int:
        """
        Return the chunk size for the LOB. Reading and writing to the LOB in
        chunks of multiples of this size will improve performance.
        """
        return self._impl.get_chunk_size()

    def getfilename(self) -> tuple:
        """
        Return a two-tuple consisting of the directory alias and file name for
        a BFILE type LOB.
        """
        return self._impl.get_file_name()

    def isopen(self) -> bool:
        """
        Return a boolean indicating if the LOB has been opened using the method
        open().
        """
        return self._impl.get_is_open()

    def open(self) -> None:
        """
        Open the LOB for writing. This will improve performance when writing to
        the LOB in chunks and there are functional or extensible indexes
        associated with the LOB. If this method is not called, each write will
        perform an open internally followed by a close after the write has been
        completed.
        """
        self._impl.open()

    def read(self, offset: int=1, amount: int=None) -> Union[str, bytes]:
        """
        Return a portion (or all) of the data in the LOB. Note that the amount
        and offset are in bytes for BLOB and BFILE type LOBs and in UCS-2 code
        points for CLOB and NCLOB type LOBs. UCS-2 code points are equivalent
        to characters for all but supplemental characters. If supplemental
        characters are in the LOB, the offset and amount will have to be chosen
        carefully to avoid splitting a character.
        """
        if amount is None:
            amount = self._impl.get_max_amount()
            if amount >= offset:
                amount = amount - offset + 1
            else:
                amount = 1
        return self._impl.read(offset, amount)

    def setfilename(self, dir_alias: str, name: str) -> None:
        """
        Set the directory alias and name of a BFILE type LOB.
        """
        self._impl.set_file_name(dir_alias, name)

    def size(self) -> int:
        """
        Returns the size of the data in the LOB. For BLOB and BFILE type LOBs
        this is the number of bytes. For CLOB and NCLOB type LOBs this is the
        number of UCS-2 code points. UCS-2 code points are equivalent to
        characters for all but supplemental characters.
        """
        return self._impl.get_size()

    def trim(self, new_size: int=0) -> None:
        """
        Trim the LOB to the new size.
        """
        self._impl.trim(new_size)

    @property
    def type(self) -> object:
        """
        Returns the type of the LOB as one of the database type constants.
        """
        return self._impl.dbtype

    def write(self, data: Union[str, bytes], offset: int=1) -> None:
        """
        Write the data to the LOB at the given offset. The offset is in bytes
        for BLOB type LOBs and in UCS-2 code points for CLOB and NCLOB type
        LOBs. UCS-2 code points are equivalent to characters for all but
        supplemental characters. If supplemental characters are in the LOB, the
        offset will have to be chosen carefully to avoid splitting a character.
        Note that if you want to make the LOB value smaller, you must use the
        trim() function.
        """
        self._impl.write(data, offset)
