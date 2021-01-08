#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#
# Portions Copyright 2007-2015, Anthony Tuininga. All rights reserved.
#
# Portions Copyright 2001-2007, Computronix (Canada) Ltd., Edmonton, Alberta,
# Canada. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# MultiConsumerAQ.py
#   This script demonstrates how to use multi-consumer
# advanced queuing using py-oracledb. It makes use of a RAW queue
# created in the sample setup.
#
# Currently, this script runs with the thick driver only.
#------------------------------------------------------------------------------

import oracledb
import sample_env

QUEUE_NAME = "DEMO_RAW_QUEUE_MULTI"
PAYLOAD_DATA = [
    "The first message",
    "The second message",
    "The third message",
    "The fourth and final message"
]

# connect to database
connection = oracledb.connect(sample_env.get_main_connect_string(),
                              thin=False)
cursor = connection.cursor()

# create queue
queue = connection.queue(QUEUE_NAME)
queue.deqOptions.wait = oracledb.DEQ_NO_WAIT
queue.deqOptions.navigation = oracledb.DEQ_FIRST_MSG

# enqueue a few messages
print("Enqueuing messages...")
for data in PAYLOAD_DATA:
    print(data)
    queue.enqOne(connection.msgproperties(payload=data))
connection.commit()
print()

# dequeue the messages for consumer A
print("Dequeuing the messages for consumer A...")
queue.deqOptions.consumername = "SUBSCRIBER_A"
while True:
    props = queue.deqOne()
    if not props:
        break
    print(props.payload.decode())
connection.commit()
print()

# dequeue the message for consumer B
print("Dequeuing the messages for consumer B...")
queue.deqOptions.consumername = "SUBSCRIBER_B"
while True:
    props = queue.deqOne()
    if not props:
        break
    print(props.payload.decode())
connection.commit()

print("\nDone.")
