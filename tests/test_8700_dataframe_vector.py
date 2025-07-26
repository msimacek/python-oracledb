# ----------------------------------------------------------------------------- 
# Copyright (c) 2025, Oracle and/or its affiliates.                             
#                                                                               
# This software is dual-licensed to you under the Universal Permissive License  
# (UPL) 1.0 as shown at https://oss.oracle.com/licenses/upl and Apache License  
# 2.0 as shown at http://www.apache.org/licenses/LICENSE-2.0. You may choose    
# either license.                                                               
#                                                                               
# If you elect to accept the software under the Apache License, Version 2.0,    
# the following applies:                                                        
#                                                                               
# Licensed under the Apache License, Version 2.0 (the "License");               
# you may not use this file except in compliance with the License.              
# You may obtain a copy of the License at                                       
#                                                                               
#    https://www.apache.org/licenses/LICENSE-2.0                                
#                                                                               
# Unless required by applicable law or agreed to in writing, software           
# distributed under the License is distributed on an "AS IS" BASIS,             
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.      
# See the License for the specific language governing permissions and           
# limitations under the License.                                                
# -----------------------------------------------------------------------------
"""
Module for testing dataframe with vector support
"""

import array
import datetime
import decimal
import unittest

import oracledb

try:
    import numpy
    import pandas
    import pyarrow

    HAS_INTEROP = True
except ImportError:
    HAS_INTEROP = False

import test_env

@unittest.skipUnless(
    test_env.has_client_version(23, 4), "unsupported client"
)
@unittest.skipUnless(
    test_env.has_server_version(23, 4), "unsupported server"
)

class TestCase(test_env.BaseTestCase):

    def __check_interop(self):
        """
        Checks to see if the pyarrow and pandas modules are available.
        """
        if not HAS_INTEROP:
            self.skipTest("missing pandas or pyarrow modules")

    def __convert_df_value(self, df_val):
        """
        This method converts a dataframe cell value to use with assertEqual()
        For e.g. NaN and np.array cannot be compared directly. Values are
        converted according to the following rules:
         - NaN -> None
         - np.array -> np.array.tolist() (Python list)
        """
        if isinstance(df_val, numpy.ndarray):
            return df_val.tolist()
        elif pandas.isna(df_val):
            return None
        elif isinstance(df_val, dict):
            return {k: self.__convert_df_value(v) for k, v in df_val.items()}
        else:
            return df_val

    def __get_data_from_df(self, df):
        """
        Returns data from the data frame in a normalized fashion suitable for
        comparison. In particular, NaN values cannot be compared to one another
        so they are converted to the value None for comparison purposes.
        """
        return [
            tuple(self.__convert_df_value(v) for v in row)
            for row in df.itertuples(index=False, name=None)
        ]

    def test_8700(self):
        "8700 - fetch float32 vector"

        # float32 is a special case while comparing dataframe values
        # Converting Dataframe cell value of type numpy.ndarray[float32]
        # using .tolist() converts each value to Python float. Python
        # float uses 64-bit precision causing mismatches in assertEqual.
        # As a workaround we use array.array('f', src).tolist() on the
        # source data
        data = [
            (array.array("f", [34.6, 77.8]).tolist(),),
            (array.array("f", [34.6, 77.8, 55.9]).tolist(),),
        ]
        self.__check_interop()
        ora_df = self.conn.fetch_df_all(
            """
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT32)
            union all
            SELECT TO_VECTOR('[34.6, 77.8, 55.9]', 3, FLOAT32)
            """
        )
        self.assertEqual(ora_df.num_rows(), 2)
        self.assertEqual(ora_df.num_columns(), 1)
        ora_col = ora_df.get_column(0)
        self.assertEqual(ora_col.null_count, 0)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        # number of children for a nested list = 1
        self.assertEqual(fetched_tab.schema.types[0].num_fields, 1)
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    def test_8701(self):
        "8701 - fetch float64 vector"
        data = [
            ([34.6, 77.8],),
            ([34.6, 77.8, 55.9],),
        ]
        self.__check_interop()
        ora_df = self.conn.fetch_df_all(
            """
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            union all
            SELECT TO_VECTOR('[34.6, 77.8, 55.9]', 3, FLOAT64)
            """
        )
        self.assertEqual(ora_df.num_rows(), 2)
        self.assertEqual(ora_df.num_columns(), 1)
        ora_col = ora_df.get_column(0)
        self.assertEqual(ora_col.null_count, 0)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        self.assertEqual(fetched_tab.schema.types[0].num_fields, 1)
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    def test_8702(self):
        "8702 - fetch int8 vector"
        data = [
            ([34, -77],),
            ([34, 77, 55],),
        ]
        self.__check_interop()
        ora_df = self.conn.fetch_df_all(
            """
            SELECT TO_VECTOR('[34, -77]', 2, INT8)
            union all
            SELECT TO_VECTOR('[34, 77, 55]', 3, INT8)
            """
        )
        self.assertEqual(ora_df.num_rows(), 2)
        self.assertEqual(ora_df.num_columns(), 1)
        ora_col = ora_df.get_column(0)
        self.assertEqual(ora_col.null_count, 0)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        self.assertEqual(fetched_tab.schema.types[0].num_fields, 1)
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    def test_8703(self):
        "8703 - fetch binary vector"
        data = [
            ([3, 2, 3],),
            ([3, 2],),
        ]
        self.__check_interop()
        ora_df = self.conn.fetch_df_all(
            """
            SELECT TO_VECTOR('[3, 2, 3]', 24, BINARY)
            union all
            SELECT TO_VECTOR('[3, 2]', 16, BINARY)
            """
        )
        self.assertEqual(ora_df.num_rows(), 2)
        self.assertEqual(ora_df.num_columns(), 1)
        ora_col = ora_df.get_column(0)
        self.assertEqual(ora_col.null_count, 0)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        self.assertEqual(fetched_tab.schema.types[0].num_fields, 1)
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    def test_8704(self):
        "8704 - fetch float32 vectors with None"
        data = [
            (array.array("f", [34.6, 77.8]).tolist(),),
            (array.array("f", [34.6, 77.8, 55.9]).tolist(),),
            (None,),
        ]
        self.__check_interop()
        ora_df = self.conn.fetch_df_all(
            """
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT32)
            union all
            SELECT TO_VECTOR('[34.6, 77.8, 55.9]', 3, FLOAT32)
            union all
            select NULL
            """
        )
        self.assertEqual(ora_df.num_rows(), 3)
        self.assertEqual(ora_df.num_columns(), 1)
        ora_col = ora_df.get_column(0)
        self.assertEqual(ora_col.null_count, 1)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        self.assertEqual(fetched_tab.schema.types[0].num_fields, 1)
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    def test_8705(self):
        "8705 - fetch duplicate float64 vectors"
        data = [
            ([34.6, 77.8],),
            ([34.6, 77.8],),
            ([34.6, 77.8],),
            ([34.6, 77.8],),
            ([34.6, 77.8],),
            ([34.6, 77.8],),
            ([34.6, 77.8],),
            ([34.6, 77.8],),
            ([34.6, 77.8],),
            ([34.6, 77.8],),
            ([34.6, 77.8],),
            ([34.6, 77.8],),
        ]
        self.__check_interop()
        ora_df = self.conn.fetch_df_all(
            """
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            union all
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            union all
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            union all
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            union all
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            union all
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            union all
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            union all
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            union all
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            union all
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            union all
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            union all
            SELECT TO_VECTOR('[34.6, 77.8]', 2, FLOAT64)
            """
        )
        self.assertEqual(ora_df.num_rows(), 12)
        self.assertEqual(ora_df.num_columns(), 1)
        ora_col = ora_df.get_column(0)
        self.assertEqual(ora_col.null_count, 0)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        self.assertEqual(fetched_tab.schema.types[0].num_fields, 1)
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    @unittest.skipUnless(
        test_env.has_client_version(23, 7), "unsupported client"
    )
    @unittest.skipUnless(
        test_env.has_server_version(23, 7), "unsupported server"
    )
    def test_8706(self):
        "8706 - fetch float32 sparse vectors"
        data = [
            (
                {
                    "num_dimensions": 8,
                    "indices": [0, 7],
                    "values": array.array("f", [34.6, 77.8]).tolist(),
                },
            ),
            (
                {
                    "num_dimensions": 8,
                    "indices": [0, 7],
                    "values": array.array("f", [34.6, 9.1]).tolist(),
                },
            ),
        ]
        self.__check_interop()
        ora_df = self.conn.fetch_df_all(
            """
            SELECT TO_VECTOR(
                TO_VECTOR('[34.6, 0, 0, 0, 0, 0, 0, 77.8]', 8, FLOAT32),
                8,
                FLOAT32,
                SPARSE
                )
            union all
            SELECT TO_VECTOR(
                TO_VECTOR('[34.6, 0, 0, 0, 0, 0, 0, 9.1]', 8, FLOAT32),
                8,
                FLOAT32,
                SPARSE
                )
            """
        )
        self.assertEqual(ora_df.num_rows(), 2)
        self.assertEqual(ora_df.num_columns(), 1)
        ora_col = ora_df.get_column(0)
        self.assertEqual(ora_col.null_count, 0)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        # number of children for a struct = 3 (num_dimensions, indices, values)
        self.assertEqual(fetched_tab.schema.types[0].num_fields, 3)
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    @unittest.skipUnless(
        test_env.has_client_version(23, 7), "unsupported client"
    )
    @unittest.skipUnless(
        test_env.has_server_version(23, 7), "unsupported server"
    )
    def test_8707(self):
        "8707 - fetch float64 sparse vectors"
        data = [
            (
                {
                    "num_dimensions": 8,
                    "indices": [0, 7],
                    "values": [34.6, 77.8],
                },
            ),
            (
                {
                    "num_dimensions": 8,
                    "indices": [0, 7],
                    "values": [34.6, 9.1],
                },
            ),
        ]
        self.__check_interop()
        ora_df = self.conn.fetch_df_all(
            """
            SELECT TO_VECTOR(
                TO_VECTOR('[34.6, 0, 0, 0, 0, 0, 0, 77.8]', 8, FLOAT64),
                8,
                FLOAT64,
                SPARSE
                )
            union all
            SELECT TO_VECTOR(
                TO_VECTOR('[34.6, 0, 0, 0, 0, 0, 0, 9.1]', 8, FLOAT64),
                8,
                FLOAT64,
                SPARSE
                )
            """
        )
        self.assertEqual(ora_df.num_rows(), 2)
        self.assertEqual(ora_df.num_columns(), 1)
        ora_col = ora_df.get_column(0)
        self.assertEqual(ora_col.null_count, 0)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        # number of children for a struct = 3 (num_dimensions, indices, values)
        self.assertEqual(fetched_tab.schema.types[0].num_fields, 3)
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    def test_8708(self):
        "8708 - DPY-3031 - Unsupported flexible vector formats"
        with self.assertRaisesFullCode("DPY-3031"):
            self.conn.fetch_df_all(
                """
                SELECT TO_VECTOR('[44, 55, 89]', 3, INT8) as flex_col
                union all
                SELECT TO_VECTOR('[34.6, 77.8, 55.9]', 3, FLOAT32) as flex_col
                """
            )

    def test_8709(self):
        "8709 - test vector operations with different dimensions"
        self.__check_interop()
        data = [
            ([1.0, 2.0, 3.0],),
            ([4.0, 5.0, 6.0, 7.0],),
            ([8.0, 9.0],)
        ]
        ora_df = self.conn.fetch_df_all(
            """
            SELECT TO_VECTOR('[1.0, 2.0, 3.0]', 3, FLOAT64)
            union all
            SELECT TO_VECTOR('[4.0, 5.0, 6.0, 7.0]', 4, FLOAT64)
            union all
            SELECT TO_VECTOR('[8.0, 9.0]', 2, FLOAT64)
            """
        )
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    def test_8710(self):
        "8710 - test vector operations with zero values in arrays"
        self.__check_interop()
        data = [
            ([1.0, 0.0, 3.0],),
            ([0.0, 5.0, 0.0],),
            ([7.0, 8.0, 9.0],)
        ]

        ora_df = self.conn.fetch_df_all("""
            SELECT TO_VECTOR('[1.0, 0.0, 3.0]', 3, FLOAT64) FROM dual
            UNION ALL
            SELECT TO_VECTOR('[0.0, 5.0, 0.0]', 3, FLOAT64) FROM dual
            UNION ALL
            SELECT TO_VECTOR('[7.0, 8.0, 9.0]', 3, FLOAT64) FROM dual
        """)

        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        fetched_df = fetched_tab.to_pandas()

        actual_data = self.__get_data_from_df(fetched_df)
        self.assertEqual(actual_data, data)

    def test_8711(self):
        "8711 - test vector operations with large arrays"
        self.__check_interop()
        large_array = list(range(1, 1001))  # 1000 elements
        data = [
            (large_array,),
            (large_array,)
        ]
        ora_df = self.conn.fetch_df_all(
            f"""
            SELECT TO_VECTOR('[{",".join(map(str, large_array))}]',
                             {len(large_array)}, FLOAT64)
            union all
            SELECT TO_VECTOR('[{",".join(map(str, large_array))}]',
                             {len(large_array)}, FLOAT64)
            """
        )
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    @unittest.skipUnless(
        test_env.has_client_version(23, 7), "unsupported client"
    )
    @unittest.skipUnless(
        test_env.has_server_version(23, 7), "unsupported server"
    )
    def test_8712(self):
        "8712 - test sparse vector operations with different dimensions"
        self.__check_interop()
        with self.assertRaisesFullCode("DPY-2065"):
            self.conn.fetch_df_all(
            """
            SELECT TO_VECTOR(
                TO_VECTOR('[0.0, 2.0, 0.0, 4.0, 0.0, 6.0, 0.0, 0.0, 0.0, 0.0]',
                         10, FLOAT64),
                10, FLOAT64, SPARSE
            )
            union all
            SELECT TO_VECTOR(
                TO_VECTOR('[1.0, 0.0, 3.0, 0.0, 5.0]', 5, FLOAT64),
                5, FLOAT64, SPARSE
            )
            """
        )

    def test_8713(self):
        "8713 - test mixed vector types in a single dataframe"
        self.__check_interop()
        data = [
            ([1.0, 2.0, 3.0], [1, 2, 3]),
            ([4.0, 5.0, 6.0], [4, 5, 6]),
        ]
        ora_df = self.conn.fetch_df_all("""
            SELECT
                TO_VECTOR('[1.0, 2.0, 3.0]', 3, FLOAT64) as float_vec,
                TO_VECTOR('[1, 2, 3]', 3, INT8) as int_vec
            FROM dual
            UNION ALL
            SELECT
                TO_VECTOR('[4.0, 5.0, 6.0]', 3, FLOAT64) as float_vec,
                TO_VECTOR('[4, 5, 6]', 3, INT8) as int_vec
            FROM dual
        """)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    def test_8714(self):
        "8714 - test vector dimension zero(empty)"

        with self.assertRaisesFullCode("ORA-51801"):
            self.conn.fetch_df_all("""
                SELECT TO_VECTOR('[]', 0, FLOAT64) FROM dual
                UNION ALL
                SELECT TO_VECTOR('[42.0]', 1, FLOAT64) FROM dual
            """)

    @unittest.skipUnless(
        test_env.has_client_version(23, 7), "unsupported client"
    )
    @unittest.skipUnless(
        test_env.has_server_version(23, 7), "unsupported server"
    )
    def test_8715(self):
        "8715 - test sparse vectors with NULL values"
        self.__check_interop()
        data = [
            (None,),
            ({
                "num_dimensions": 5,
                "indices": [0, 2, 4],
                "values": [1.0, 3.0, 5.0]
            },)
        ]
        ora_df = self.conn.fetch_df_all("""
            SELECT NULL
            UNION ALL
            SELECT TO_VECTOR(
                TO_VECTOR('[1.0, 0.0, 3.0, 0.0, 5.0]', 5, FLOAT64),
                5, FLOAT64, SPARSE
            )
        """)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    def test_8716(self):
        "8716 - test vectors with very large dimensions"
        self.__check_interop()
        large_dim = 999
        large_vector = [0.0] * large_dim
        large_vector[0] = 1.0
        large_vector[-1] = 1.0
        data = [
            (large_vector,),
        ]
        vector_str = '[' + ','.join(map(str, large_vector)) + ']'
        ora_df = self.conn.fetch_df_all(f"""
            SELECT TO_VECTOR('{vector_str}', {large_dim}, FLOAT64)
        """)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    def test_8717(self):
        "8717 - test vectors with non-uniform data (mixed positive/negative values)"
        self.__check_interop()
        data = [
            ([-1.0, 2.0, -3.0],),
            ([4.0, -5.0, 6.0],),
        ]
        ora_df = self.conn.fetch_df_all("""
            SELECT TO_VECTOR('[-1.0, 2.0, -3.0]', 3, FLOAT64)
            UNION ALL
            SELECT TO_VECTOR('[4.0, -5.0, 6.0]', 3, FLOAT64)
        """)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

    def test_8718(self):
        "8718 - test vector precision for float32 and float64"
        self.__check_interop()

        data_float32 = [
            (array.array("f", [1.2345678, 9.8765432]).tolist(),),
        ]
        ora_df_float32 = self.conn.fetch_df_all("""
            SELECT TO_VECTOR('[1.2345678, 9.8765432]', 2, FLOAT32)
        """)
        fetched_df_float32 = pyarrow.Table.from_arrays(
            ora_df_float32.column_arrays(),
            names=ora_df_float32.column_names()
        ).to_pandas()

        data_float64 = [
            ([1.234567890123456, 9.876543210987654],),
        ]
        ora_df_float64 = self.conn.fetch_df_all("""
            SELECT TO_VECTOR('[1.234567890123456, 9.876543210987654]', 2, FLOAT64)
        """)
        fetched_df_float64 = pyarrow.Table.from_arrays(
            ora_df_float64.column_arrays(),
            names=ora_df_float64.column_names()
        ).to_pandas()

        # Float32 comparison (7 decimal places)
        numpy.testing.assert_array_almost_equal(
            numpy.array(data_float32[0][0]),
            numpy.array(self.__get_data_from_df(fetched_df_float32)[0][0]),
            decimal=7
        )

        # Float64 comparison (14 decimal places)
        numpy.testing.assert_array_almost_equal(
            numpy.array(data_float64[0][0]),
            numpy.array(self.__get_data_from_df(fetched_df_float64)[0][0]),
            decimal=14
        )

    def test_8719(self):
        "8719 - test binary vector edge case - empty"
        self.__check_interop()
        with self.assertRaisesFullCode("ORA-51801"):
            self.conn.fetch_df_all("""
                SELECT TO_VECTOR('[]', 0, BINARY)
                UNION ALL
                SELECT TO_VECTOR('[255, 0, 255]', 24, BINARY)
            """)

    def test_8720(self):
        "8719 - test binary vector edge case - max value"
        self.__check_interop()
        data = [
            ([255, 255, 255],),
            ([255, 0, 255],),
        ]
        ora_df = self.conn.fetch_df_all("""
            SELECT TO_VECTOR('[255, 255, 255]', 24, BINARY)
            UNION ALL
            SELECT TO_VECTOR('[255, 0, 255]', 24, BINARY)
        """)
        fetched_tab = pyarrow.Table.from_arrays(
            ora_df.column_arrays(), names=ora_df.column_names()
        )
        fetched_df = fetched_tab.to_pandas()
        self.assertEqual(data, self.__get_data_from_df(fetched_df))

if __name__ == "__main__":
    test_env.run_test_cases()
