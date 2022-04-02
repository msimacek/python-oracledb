#------------------------------------------------------------------------------
# Copyright (c) 2020, 2022, Oracle and/or its affiliates.
#
# Portions Copyright 2007-2015, Anthony Tuininga. All rights reserved.
#
# Portions Copyright 2001-2007, Computronix (Canada) Ltd., Edmonton, Alberta,
# Canada. All rights reserved.
#
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# multi_consumer_aq.py
#
# Demonstrates how to use multi-consumer advanced queuing. It makes use of a
# RAW queue created in the sample setup.
#------------------------------------------------------------------------------

import oracledb
import sample_env

# this script is currently only supported in python-oracledb thick mode
oracledb.init_oracle_client()

QUEUE_NAME = "DEMO_RAW_QUEUE_MULTI"
PAYLOAD_DATA = [
    "The first message",
    "The second message",
    "The third message",
    "The fourth and final message"
]

# connect to database
connection = oracledb.connect(sample_env.get_main_connect_string())
cursor = connection.cursor()

# create queue
queue = connection.queue(QUEUE_NAME)
queue.deqoptions.wait = oracledb.DEQ_NO_WAIT
queue.deqoptions.navigation = oracledb.DEQ_FIRST_MSG

# enqueue a few messages
print("Enqueuing messages...")
for data in PAYLOAD_DATA:
    print(data)
    queue.enqone(connection.msgproperties(payload=data))
connection.commit()
print()

# dequeue the messages for consumer A
print("Dequeuing the messages for consumer A...")
queue.deqoptions.consumername = "SUBSCRIBER_A"
while True:
    props = queue.deqone()
    if not props:
        break
    print(props.payload.decode())
connection.commit()
print()

# dequeue the message for consumer B
print("Dequeuing the messages for consumer B...")
queue.deqoptions.consumername = "SUBSCRIBER_B"
while True:
    props = queue.deqone()
    if not props:
        break
    print(props.payload.decode())
connection.commit()

print("\nDone.")
