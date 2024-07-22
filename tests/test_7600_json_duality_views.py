# -----------------------------------------------------------------------------
# Copyright (c) 2020, 2024, Oracle and/or its affiliates.
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
7500 - Module for testing JSON Duality Views
"""

import unittest

import test_env


@unittest.skipIf(
    test_env.get_server_version() < (23, 4)
    and test_env.get_client_version() < (23, 4),
    "unsupported server",
)
@unittest.skipIf(
    test_env.skip_soda_tests(), "unsupported client/server combination"
)
class TestCase(test_env.BaseTestCase):

    def test_7500(self):
        "7500 - insert document in json duality view remove by key"
        soda_db = self.get_soda_database()
        coll = soda_db.createCollection(
            "TestSodaJDV", metadata={"dualityViewName": "PROJ_DUALV"}
        )
        coll.find().remove()
        value = {
            "proj_id": 4,
            "proj_name": "Business Object Views and New",
            "proj_status": "active",
            "specs": [
                {
                    "spec_id": 3,
                    "spec_name": "Test Spec BOV4",
                    "last_mod": "2021-06-01T15:00:10",
                }
            ],
        }
        key = coll.insertOneAndGet(value).key
        output = coll.find().key(key).getOne().getContent()
        exp_value = {
            "proj_id": output["proj_id"],
            "proj_name": output["proj_name"],
            "proj_status": output["proj_status"],
            "specs": output["specs"],
        }
        self.__normalize_docs([exp_value])
        self.assertEqual(exp_value, value)

        output1 = coll.find().filter({"proj_id": 4}).getOne().getContent()
        exp_value1 = {
            "proj_id": output1["proj_id"],
            "proj_name": output1["proj_name"],
            "proj_status": output1["proj_status"],
            "specs": output1["specs"],
        }
        self.__normalize_docs([exp_value1])
        self.assertEqual(exp_value1, value)

        output2 = (
            coll.find().filter({"proj_id": {"$eq": 4}}).getOne().getContent()
        )
        exp_value1 = {
            "proj_id": output2["proj_id"],
            "proj_name": output2["proj_name"],
            "proj_status": output2["proj_status"],
            "specs": output2["specs"],
        }
        self.__normalize_docs([exp_value1])
        self.assertEqual(exp_value1, value)

        output = coll.find().key(key).remove()
        output = coll.find().key(key).getOne()
        self.assertEqual(None, output)

    def test_7501(self):
        """
        7501 - insert multiple documents in json duality view and remove by
        filter
        """
        soda_db = self.get_soda_database()
        coll = soda_db.createCollection(
            "TestSodaJDV", metadata={"dualityViewName": "PROJ_DUALV"}
        )
        coll.find().remove()
        values = [
            {
                "proj_id": 4,
                "proj_name": "Business Object Views and New",
                "proj_status": "active",
                "specs": [
                    {
                        "spec_id": 3,
                        "spec_name": "Test Spec BOV",
                        "last_mod": "2021-06-01T15:00:10",
                    }
                ],
            },
            {
                "proj_id": 5,
                "proj_name": "Business Object New",
                "proj_status": "inactive",
                "specs": [
                    {
                        "spec_id": 4,
                        "spec_name": "Test Spec4",
                        "last_mod": "2021-07-01T15:00:10",
                    }
                ],
            },
            {
                "proj_id": 6,
                "proj_name": "Business Object New6",
                "proj_status": "active",
                "specs": [
                    {
                        "spec_id": 5,
                        "spec_name": "Test Spec5",
                        "last_mod": "2022-07-01T15:00:10",
                    }
                ],
            },
        ]
        coll.insertMany(values)
        docs = coll.find().lock().getDocuments()
        exp_values = []
        for doc in docs:
            output = doc.getContent()
            exp_value = {
                "proj_id": output["proj_id"],
                "proj_name": output["proj_name"],
                "proj_status": output["proj_status"],
                "specs": output["specs"],
            }
            self.__normalize_docs([exp_value])
            exp_values.append(exp_value)

        self.assertEqual(exp_values, values)

        # remove
        coll.find().filter({"proj_id": {"$eq": 4}}).remove()
        output2 = coll.find().filter({"proj_id": {"$eq": 4}}).getOne()
        self.assertEqual(None, output2)

    def test_7502(self):
        "7502 - insert document and replace in json duality view"
        soda_db = self.get_soda_database()
        coll = soda_db.createCollection(
            "TestSodaJDV", metadata={"dualityViewName": "PROJ_DUALV"}
        )
        coll.find().remove()
        value = {
            "proj_id": 4,
            "proj_name": "Business Object Views and New",
            "proj_status": "active",
            "specs": [
                {
                    "spec_id": 3,
                    "spec_name": "Test Spec BOV",
                    "last_mod": "2021-06-01T15:00:10",
                }
            ],
        }
        key = coll.insertOneAndGet(value).key
        new_value = {
            "proj_id": 4,
            "proj_name": "Business Object Views5",
            "proj_status": "inactive",
            "specs": [
                {
                    "spec_id": 4,
                    "spec_name": "Test Spec4",
                    "last_mod": "2022-07-01T15:00:10",
                }
            ],
        }
        coll.find().key(key).replaceOne(new_value)
        output = coll.find().key(key).getOne().getContent()
        exp_value = {
            "proj_id": output["proj_id"],
            "proj_name": output["proj_name"],
            "proj_status": output["proj_status"],
            "specs": output["specs"],
        }
        self.__normalize_docs([exp_value])
        self.assertEqual(exp_value, new_value)

    def test_7503(self):
        "7503 - insert document and replace by version in json duality view"
        soda_db = self.get_soda_database()
        coll = soda_db.createCollection(
            "TestSodaJDV", metadata={"dualityViewName": "PROJ_DUALV"}
        )
        coll.find().remove()
        value = {
            "proj_id": 4,
            "proj_name": "Business Object Views and New",
            "proj_status": "active",
            "specs": [
                {
                    "spec_id": 3,
                    "spec_name": "Test Spec BOV",
                    "last_mod": "2021-06-01T15:00:10",
                }
            ],
        }
        doc = coll.insertOneAndGet(value)
        key = doc.key
        version = doc.version
        new_value = {
            "proj_id": 4,
            "proj_name": "Business Object Views5",
            "proj_status": "inactive",
            "specs": [
                {
                    "spec_id": 4,
                    "spec_name": "Test Spec4",
                    "last_mod": "2022-07-01T15:00:10",
                }
            ],
        }
        coll.find().key(key).version(version).replaceOne(new_value)
        output_doc = coll.find().key(key).getOne()
        version = output_doc.version
        output = output_doc.getContent()
        exp_value = {
            "proj_id": output["proj_id"],
            "proj_name": output["proj_name"],
            "proj_status": output["proj_status"],
            "specs": output["specs"],
        }
        self.__normalize_docs([exp_value])
        self.assertEqual(exp_value, new_value)

        coll.find().key(key).version(version).remove()
        output = coll.find().key(key).getOne()
        self.assertEqual(None, output)

    def test_7504(self):
        "7504 - test skip and limit on json duality views"
        soda_db = self.get_soda_database()
        coll = soda_db.createCollection(
            "TestSodaJDV", metadata={"dualityViewName": "PROJ_DUALV"}
        )
        coll.find().remove()
        values = [
            {
                "proj_id": 1,
                "proj_name": "Business Object Views and New",
                "proj_status": "active",
                "specs": [
                    {
                        "spec_id": 2,
                        "spec_name": "Test Spec BOV",
                        "last_mod": "2021-06-01T15:00:10",
                    }
                ],
            },
            {
                "proj_id": 2,
                "proj_name": "Business Object Views2",
                "proj_status": "inactive",
                "specs": [
                    {
                        "spec_id": 3,
                        "spec_name": "Test Spec4",
                        "last_mod": "2021-07-01T15:00:10",
                    }
                ],
            },
            {
                "proj_id": 3,
                "proj_name": "Business Object Views3",
                "proj_status": "active",
                "specs": [
                    {
                        "spec_id": 5,
                        "spec_name": "Test Spec5",
                        "last_mod": "2022-07-01T15:00:10",
                    }
                ],
            },
            {
                "proj_id": 4,
                "proj_name": "Business Object View4",
                "proj_status": "inactive",
                "specs": [
                    {
                        "spec_id": 6,
                        "spec_name": "Test Spec6",
                        "last_mod": "2021-07-01T15:00:10",
                    }
                ],
            },
            {
                "proj_id": 5,
                "proj_name": "Business Object New5",
                "proj_status": "active",
                "specs": [
                    {
                        "spec_id": 7,
                        "spec_name": "Test Spec5",
                        "last_mod": "2022-07-01T15:00:10",
                    }
                ],
            },
        ]
        coll.insertMany(values)

        docs = coll.find().skip(0).limit(2).getDocuments()
        exp_values = []
        for doc in docs:
            output = doc.getContent()
            exp_value = {
                "proj_id": output["proj_id"],
                "proj_name": output["proj_name"],
                "proj_status": output["proj_status"],
                "specs": output["specs"],
            }
            self.__normalize_docs([exp_value])
            exp_values.append(exp_value)

        self.assertEqual(exp_values, [values[0], values[1]])

        docs = coll.find().skip(2).limit(5).getDocuments()
        exp_values = []
        for doc in docs:
            output = doc.getContent()
            exp_value = {
                "proj_id": output["proj_id"],
                "proj_name": output["proj_name"],
                "proj_status": output["proj_status"],
                "specs": output["specs"],
            }
            self.__normalize_docs([exp_value])
            exp_values.append(exp_value)

        self.assertEqual(exp_values, [values[2], values[3], values[4]])

    def test_7505(self):
        "7505 - insert document in json duality view with varchar2 primary key"
        soda_db = self.get_soda_database()
        coll = soda_db.createCollection(
            "TestSodaJDV2", metadata={"dualityViewName": "PROJ_DUALV2"}
        )
        coll.find().remove()
        value = {
            "proj_id": "4",
            "proj_name": "Business Object Views and New",
            "proj_status": "active",
            "specs": [
                {
                    "spec_id": 3,
                    "spec_name": "Test Spec BOV4",
                    "last_mod": "2021-06-01T15:00:10",
                }
            ],
        }
        key = coll.insertOneAndGet(value).key
        output = coll.find().key(key).getOne().getContent()
        exp_value = {
            "proj_id": output["proj_id"],
            "proj_name": output["proj_name"],
            "proj_status": output["proj_status"],
            "specs": output["specs"],
        }
        self.__normalize_docs([exp_value])
        self.assertEqual(exp_value, value)

        output1 = coll.find().filter({"proj_id": "4"}).getOne().getContent()
        exp_value1 = {
            "proj_id": output1["proj_id"],
            "proj_name": output1["proj_name"],
            "proj_status": output1["proj_status"],
            "specs": output1["specs"],
        }
        self.__normalize_docs([exp_value1])
        self.assertEqual(exp_value1, value)

        output2 = (
            coll.find().filter({"proj_id": {"$eq": "4"}}).getOne().getContent()
        )
        exp_value1 = {
            "proj_id": output2["proj_id"],
            "proj_name": output2["proj_name"],
            "proj_status": output2["proj_status"],
            "specs": output2["specs"],
        }
        self.__normalize_docs([exp_value1])
        self.assertEqual(exp_value1, value)

        output = coll.find().key(key).remove()
        output = coll.find().key(key).getOne()
        self.assertEqual(None, output)

    def test_7506(self):
        "7506 - verify sodadoc.key is same as embedded oid"
        soda_db = self.get_soda_database()
        coll = soda_db.createCollection("TestSodaEOID")
        self.assertEqual(
            coll.metadata["keyColumn"]["assignmentMethod"], "EMBEDDED_OID"
        )
        coll.find().remove()
        doc = coll.insertOneAndGet({"name": "Bob", "age": 46})
        key = doc.key
        doc1 = coll.find().key(key).getOne().getContent()
        self.assertEqual("08" + doc1["_id"].upper(), key)

    def test_7507(self):
        "7507 - insert string as embedded oid"
        soda_db = self.get_soda_database()
        coll = soda_db.createCollection("TestSodaEOID")
        coll.find().remove()
        value_to_insert = {"_id": "mykey", "name": "Bob", "age": 46}
        doc = coll.insertOneAndGet(value_to_insert)
        key = bytes.fromhex(doc.key).decode("ascii")
        self.assertEqual(key, "\x04mykey")

        doc1 = coll.find().filter({"_id": "mykey"}).getOne().getContent()
        self.assertEqual(doc1, value_to_insert)

    def test_7508(self):
        "7508 - insert number as embedded oid"
        soda_db = self.get_soda_database()
        coll = soda_db.createCollection("TestSodaEOID")
        coll.find().remove()
        value_to_insert = {"_id": 10, "name": "Bob", "age": 46}
        doc = coll.insertOneAndGet(value_to_insert)
        self.assertEqual(doc.key, "03C10B")

        doc1 = coll.find().filter({"_id": 10}).getOne().getContent()
        self.assertEqual(doc1, value_to_insert)

    def test_7509(self):
        "7509 - replace document using with user embedded oid"
        soda_db = self.get_soda_database()
        coll = soda_db.createCollection("TestSodaEOID")
        content = {"_id": "key", "name": "John", "address": {"city": "Sydney"}}
        doc = coll.insertOneAndGet(content)
        key = doc.key
        new_content = {
            "_id": 10,
            "name": "John",
            "address": {"city": "Melbourne"},
        }
        coll.find().key(key).replaceOne(new_content)
        self.conn.commit()

        # previous key should be replaced
        self.assertEqual(None, coll.find().key(key).getOne())

        doc1 = coll.find().filter({"_id": 10}).getOne()
        self.assertEqual(doc1.key, "03C10B")

        self.assertEqual(doc1.getContent(), new_content)


if __name__ == "__main__":
    test_env.run_test_cases()
