#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates.
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
#------------------------------------------------------------------------------

"""
2700 - Module for testing AQ
"""

import datetime
import decimal
import threading
import unittest

import oracledb
import test_env

@unittest.skipIf(test_env.get_is_thin(), "thin mode doesn't support AQ yet")
class TestCase(test_env.BaseTestCase):
    book_type_name = "UDT_BOOK"
    book_queue_name = "TEST_BOOK_QUEUE"
    book_data = [
        ("Wings of Fire", "A.P.J. Abdul Kalam", decimal.Decimal("15.75")),
        ("The Story of My Life", "Hellen Keller", decimal.Decimal("10.50")),
        ("The Chronicles of Narnia", "C.S. Lewis", decimal.Decimal("25.25"))
    ]
    json_queue_name = "TEST_JSON_QUEUE"
    json_data = [
        [
            2.75,
            True,
            'Ocean Beach',
            b'Some bytes',
            {'keyA': 1.0, 'KeyB': 'Melbourne'},
            datetime.datetime(2022, 8, 1, 0, 0)
        ],
        [
            True,
            False,
            'String',
            b'Some Bytes',
            {},
            {"name": None},
            {"name": "John"},
            {"age": 30},
            {"Permanent": True},
            {
                "employee": {
                    "name":"John",
                    "age": 30,
                    "city": "Delhi",
                    "Parmanent": True
                }
            },
            {
                "employees": ["John", "Matthew", "James"]
            },
            {
                "employees": [
                    {
                        "employee1": {"name": "John", "city": "Delhi"}
                    },
                    {
                        "employee2": {"name": "Matthew", "city": "Mumbai"}
                    },
                    {
                        "employee3": {"name": "James", "city": "Bangalore"}
                    }
                ]
            }
        ],
        [
            datetime.datetime.today(),
            datetime.datetime(2004, 2, 1, 3, 4, 5),
            datetime.datetime(2020, 12, 2, 13, 29, 14),
            datetime.timedelta(8.5),
            datetime.datetime(2002, 12, 13, 9, 36, 0),
            oracledb.Timestamp(2002, 12, 13, 9, 36, 0),
            datetime.datetime(2002, 12, 13)
        ],
        dict(name="John", age=30, city="New York"),
        [
            0,
            1,
            25.25,
            6088343244,
            -9999999999999999999,
            decimal.Decimal("0.25"),
            decimal.Decimal("10.25"),
            decimal.Decimal("319438950232418390.273596")
        ]
    ]

    def __deq_in_thread(self, results):
        with test_env.get_connection() as connection:
            books_type = connection.gettype(self.book_type_name)
            queue = connection.queue(self.book_queue_name, books_type)
            queue.deqoptions.wait = 10
            props = queue.deqone()
            if props is not None:
                book = props.payload
                results.append((book.TITLE, book.AUTHORS, book.PRICE))
            connection.commit()

    def __verify_attr(self, obj, attrName, value):
        setattr(obj, attrName, value)
        self.assertEqual(getattr(obj, attrName), value)


    def test_2723_enqtime(self):
        "2723 - test message props enqtime"
        queue = self.get_and_clear_queue(self.book_queue_name,
                                         self.book_type_name)
        book = queue.payload_type.newobject()
        self.cursor.execute("select sysdate from dual")
        start_date, = self.cursor.fetchone()
        props = self.connection.msgproperties(payload=book)
        queue.enqone(props)
        props = queue.deqone()
        self.cursor.execute("select sysdate from dual")
        end_date, = self.cursor.fetchone()
        self.assertTrue(start_date <= props.enqtime <= end_date)

if __name__ == "__main__":
    test_env.run_test_cases()
