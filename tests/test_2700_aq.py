#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

"""
2700 - Module for testing AQ
"""

import test_env

import oracledb
import decimal
import threading
import unittest

@unittest.skipIf(test_env.get_is_thin(), "thin driver doesn't support AQ yet")
class TestCase(test_env.BaseTestCase):
    book_type_name = "UDT_BOOK"
    book_queue_name = "TEST_BOOK_QUEUE"
    book_data = [
        ("Wings of Fire", "A.P.J. Abdul Kalam", decimal.Decimal("15.75")),
        ("The Story of My Life", "Hellen Keller", decimal.Decimal("10.50")),
        ("The Chronicles of Narnia", "C.S. Lewis", decimal.Decimal("25.25"))
    ]

    def __clear_books_queue(self):
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
        queue.deqOptions.deliverymode = oracledb.MSG_PERSISTENT_OR_BUFFERED
        queue.deqOptions.visibility = oracledb.ENQ_IMMEDIATE
        while queue.deqOne():
            pass

    def __deq_in_thread(self, results):
        connection = test_env.get_connection(threaded=True)
        books_type = connection.gettype(self.book_type_name)
        queue = connection.queue(self.book_queue_name, books_type)
        queue.deqOptions.wait = 10
        props = queue.deqOne()
        if props is not None:
            book = props.payload
            results.append((book.TITLE, book.AUTHORS, book.PRICE))
        connection.commit()

    def __verify_attr(self, obj, attrName, value):
        setattr(obj, attrName, value)
        self.assertEqual(getattr(obj, attrName), value)

    def test_2700_deq_empty(self):
        "2700 - test dequeuing an empty queue"
        self.__clear_books_queue()
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
        props = queue.deqOne()
        self.assertTrue(props is None)

    def test_2701_deq_enq(self):
        "2701 - test enqueuing and dequeuing multiple messages"
        self.__clear_books_queue()
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        props = self.connection.msgproperties()
        for title, authors, price in self.book_data:
            props.payload = book = books_type.newobject()
            book.TITLE = title
            book.AUTHORS = authors
            book.PRICE = price
            queue.enqOne(props)
        queue.deqOptions.navigation = oracledb.DEQ_FIRST_MSG
        queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
        results = []
        while True:
            props = queue.deqOne()
            if props is None:
                break
            book = props.payload
            row = (book.TITLE, book.AUTHORS, book.PRICE)
            results.append(row)
        self.connection.commit()
        self.assertEqual(results, self.book_data)

    def test_2702_deq_mode_remove_no_data(self):
        "2702 - test dequeuing with DEQ_REMOVE_NODATA option"
        self.__clear_books_queue()
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        book = books_type.newobject()
        title, authors, price = self.book_data[1]
        book.TITLE = title
        book.AUTHORS = authors
        book.PRICE = price
        props = self.connection.msgproperties(payload=book)
        queue.enqOne(props)
        queue.deqOptions.navigation = oracledb.DEQ_FIRST_MSG
        queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
        queue.deqOptions.mode = oracledb.DEQ_REMOVE_NODATA
        props = queue.deqOne()
        self.assertTrue(props is not None)
        self.assertTrue(props.payload.TITLE is None)

    def test_2703_deq_options(self):
        "2703 - test getting/setting dequeue options attributes"
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        options = queue.deqOptions
        self.__verify_attr(options, "condition", "TEST_CONDITION")
        self.__verify_attr(options, "consumername", "TEST_CONSUMERNAME")
        self.__verify_attr(options, "correlation", "TEST_CORRELATION")
        self.__verify_attr(options, "mode", oracledb.DEQ_LOCKED)
        self.__verify_attr(options, "navigation",
                           oracledb.DEQ_NEXT_TRANSACTION)
        self.__verify_attr(options, "transformation", "TEST_TRANSFORMATION")
        self.__verify_attr(options, "visibility", oracledb.ENQ_IMMEDIATE)
        self.__verify_attr(options, "wait", 1287)
        self.__verify_attr(options, "msgid", b'mID')

    def test_2704_deq_with_wait(self):
        "2704 - test waiting for dequeue"
        self.__clear_books_queue()
        results = []
        thread = threading.Thread(target=self.__deq_in_thread,
                                  args=(results,))
        thread.start()
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        book = books_type.newobject()
        title, authors, price = self.book_data[0]
        book.TITLE = title
        book.AUTHORS = authors
        book.PRICE = price
        props = self.connection.msgproperties(payload=book)
        queue.enqOne(props)
        self.connection.commit()
        thread.join()
        self.assertEqual(results, [(title, authors, price)])

    def test_2705_enq_options(self):
        "2705 - test getting/setting enqueue options attributes"
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        options = queue.enqOptions
        self.__verify_attr(options, "visibility", oracledb.ENQ_IMMEDIATE)

    def test_2706_errors_for_invalid_values(self):
        "2706 - test errors for invalid values for enqueue"
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        book = books_type.newobject()
        self.assertRaises(TypeError, queue.enqOne, book)

    def test_2707_msg_props(self):
        "2707 - test getting/setting message properties attributes"
        props = self.connection.msgproperties()
        self.__verify_attr(props, "correlation", "TEST_CORRELATION")
        self.__verify_attr(props, "delay", 60)
        self.__verify_attr(props, "exceptionq", "TEST_EXCEPTIONQ")
        self.__verify_attr(props, "expiration", 30)
        self.assertEqual(props.attempts, 0)
        self.__verify_attr(props, "priority", 1)
        self.__verify_attr(props, "msgid", b'mID')
        self.assertEqual(props.state, oracledb.MSG_READY)
        self.assertEqual(props.deliverymode, 0)

    def test_2708_visibility_mode_commit(self):
        "2708 - test enqueue visibility option - ENQ_ON_COMMIT"
        self.__clear_books_queue()
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        book = books_type.newobject()
        book.TITLE, book.AUTHORS, book.PRICE = self.book_data[0]
        queue.enqOptions.visibility = oracledb.ENQ_ON_COMMIT
        props = self.connection.msgproperties(payload=book)
        queue.enqOne(props)

        other_connection = test_env.get_connection()
        books_type = other_connection.gettype(self.book_type_name)
        queue = other_connection.queue(self.book_queue_name, books_type)
        queue.deqOptions.navigation = oracledb.DEQ_FIRST_MSG
        queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
        props = queue.deqOne()
        self.assertTrue(props is None)
        self.connection.commit()
        props = queue.deqOne()
        self.assertTrue(props is not None)

    def test_2709_visibility_mode_immediate(self):
        "2709 - test enqueue visibility option - ENQ_IMMEDIATE"
        self.__clear_books_queue()
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        book = books_type.newobject()
        book.TITLE, book.AUTHORS, book.PRICE = self.book_data[0]
        queue.enqOptions.visibility = oracledb.ENQ_IMMEDIATE
        props = self.connection.msgproperties(payload=book)
        queue.enqOne(props)

        other_connection = test_env.get_connection()
        books_type = other_connection.gettype(self.book_type_name)
        queue = other_connection.queue(self.book_queue_name, books_type)
        queue.deqOptions.navigation = oracledb.DEQ_FIRST_MSG
        queue.deqOptions.visibility = oracledb.DEQ_ON_COMMIT
        queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
        props = queue.deqOne()
        book = props.payload
        results = (book.TITLE, book.AUTHORS, book.PRICE)
        other_connection.commit()
        self.assertEqual(results, self.book_data[0])

    def test_2710_delivery_mode_same_buffered(self):
        "2710 - test enqueue/dequeue delivery modes identical - buffered"
        self.__clear_books_queue()
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        book = books_type.newobject()
        book.TITLE, book.AUTHORS, book.PRICE = self.book_data[0]
        queue.enqOptions.deliverymode = oracledb.MSG_BUFFERED
        queue.enqOptions.visibility = oracledb.ENQ_IMMEDIATE
        props = self.connection.msgproperties(payload=book)
        queue.enqOne(props)

        other_connection = test_env.get_connection()
        books_type = other_connection.gettype(self.book_type_name)
        queue = other_connection.queue(self.book_queue_name, books_type)
        queue.deqOptions.deliverymode = oracledb.MSG_BUFFERED
        queue.deqOptions.navigation = oracledb.DEQ_FIRST_MSG
        queue.deqOptions.visibility = oracledb.DEQ_IMMEDIATE
        queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
        props = queue.deqOne()
        book = props.payload
        results = (book.TITLE, book.AUTHORS, book.PRICE)
        other_connection.commit()
        self.assertEqual(results, self.book_data[0])

    def test_2711_delivery_mode_same_persistent(self):
        "2711 - test enqueue/dequeue delivery modes identical - persistent"
        self.__clear_books_queue()
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        book = books_type.newobject()
        book.TITLE, book.AUTHORS, book.PRICE = self.book_data[0]
        queue.enqOptions.deliverymode = oracledb.MSG_PERSISTENT
        queue.enqOptions.visibility = oracledb.ENQ_IMMEDIATE
        props = self.connection.msgproperties(payload=book)
        queue.enqOne(props)

        other_connection = test_env.get_connection()
        books_type = other_connection.gettype(self.book_type_name)
        queue = other_connection.queue(self.book_queue_name, books_type)
        queue.deqOptions.deliverymode = oracledb.MSG_PERSISTENT
        queue.deqOptions.navigation = oracledb.DEQ_FIRST_MSG
        queue.deqOptions.visibility = oracledb.DEQ_IMMEDIATE
        queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
        props = queue.deqOne()
        book = props.payload
        results = (book.TITLE, book.AUTHORS, book.PRICE)
        other_connection.commit()
        self.assertEqual(results, self.book_data[0])

    def test_2712_delivery_mode_same_persistent_buffered(self):
        "2712 - test enqueue/dequeue delivery modes the same"
        self.__clear_books_queue()
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        book = books_type.newobject()
        book.TITLE, book.AUTHORS, book.PRICE = self.book_data[0]
        queue.enqOptions.deliverymode = oracledb.MSG_PERSISTENT_OR_BUFFERED
        queue.enqOptions.visibility = oracledb.ENQ_IMMEDIATE
        props = self.connection.msgproperties(payload=book)
        queue.enqOne(props)

        other_connection = test_env.get_connection()
        books_type = other_connection.gettype(self.book_type_name)
        queue = other_connection.queue(self.book_queue_name, books_type)
        queue.deqOptions.deliverymode = oracledb.MSG_PERSISTENT_OR_BUFFERED
        queue.deqOptions.navigation = oracledb.DEQ_FIRST_MSG
        queue.deqOptions.visibility = oracledb.DEQ_IMMEDIATE
        queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
        props = queue.deqOne()
        book = props.payload
        results = (book.TITLE, book.AUTHORS, book.PRICE)
        other_connection.commit()
        self.assertEqual(results, self.book_data[0])

    def test_2713_delivery_mode_different(self):
        "2713 - test enqueue/dequeue delivery modes different"
        self.__clear_books_queue()
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        book = books_type.newobject()
        book.TITLE, book.AUTHORS, book.PRICE = self.book_data[0]
        queue.enqOptions.deliverymode = oracledb.MSG_BUFFERED
        queue.enqOptions.visibility = oracledb.ENQ_IMMEDIATE
        props = self.connection.msgproperties(payload=book)
        queue.enqOne(props)

        other_connection = test_env.get_connection()
        books_type = other_connection.gettype(self.book_type_name)
        queue = other_connection.queue(self.book_queue_name, books_type)
        queue.deqOptions.deliverymode = oracledb.MSG_PERSISTENT
        queue.deqOptions.navigation = oracledb.DEQ_FIRST_MSG
        queue.deqOptions.visibility = oracledb.DEQ_IMMEDIATE
        queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
        props = queue.deqOne()
        self.assertTrue(props is None)

    def test_2714_dequeue_transformation(self):
        "2714 - test dequeue transformation"
        self.__clear_books_queue()
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        book = books_type.newobject()
        book.TITLE, book.AUTHORS, book.PRICE = self.book_data[0]
        expected_price = book.PRICE + 10
        props = self.connection.msgproperties(payload=book)
        queue.enqOne(props)
        self.connection.commit()

        other_connection = test_env.get_connection()
        books_type = other_connection.gettype(self.book_type_name)
        queue = other_connection.queue(self.book_queue_name, books_type)
        queue.deqOptions.navigation = oracledb.DEQ_FIRST_MSG
        queue.deqOptions.visibility = oracledb.DEQ_IMMEDIATE
        queue.deqOptions.transformation = \
                "%s.transform2" % self.connection.username
        queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
        props = queue.deqOne()
        self.assertEqual(props.payload.PRICE, expected_price)

    def test_2715_enqueue_transformation(self):
        "2715 - test enqueue transformation"
        self.__clear_books_queue()
        books_type = self.connection.gettype(self.book_type_name)
        queue = self.connection.queue(self.book_queue_name, books_type)
        book = books_type.newobject()
        book.TITLE, book.AUTHORS, book.PRICE = self.book_data[0]
        expected_price = book.PRICE + 5
        queue.enqOptions.transformation = \
                "%s.transform1" % self.connection.username
        props = self.connection.msgproperties(payload=book)
        queue.enqOne(props)
        self.connection.commit()

        other_connection = test_env.get_connection()
        books_type = other_connection.gettype(self.book_type_name)
        queue = other_connection.queue(self.book_queue_name, books_type)
        queue.deqOptions.navigation = oracledb.DEQ_FIRST_MSG
        queue.deqOptions.visibility = oracledb.DEQ_IMMEDIATE
        queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
        props = queue.deqOne()
        self.assertEqual(props.payload.PRICE, expected_price)

if __name__ == "__main__":
    test_env.run_test_cases()
