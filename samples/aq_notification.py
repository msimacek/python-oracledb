#------------------------------------------------------------------------------
# Copyright (c) 2018, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# aq_notification.py
#   This script demonstrates using advanced queuing notification. Once this
# script is running, use another session to enqueue a few messages to the
# "DEMO_BOOK_QUEUE" queue. This is most easily accomplished by running the
# object_aq.py sample.
#------------------------------------------------------------------------------

import time

import oracledb
import sample_env

# this script only supports the thick driver currently
oracledb.defaults.thin = False

registered = True

def process_messages(message):
    global registered
    print("Message type:", message.type)
    if message.type == oracledb.EVENT_DEREG:
        print("Deregistration has taken place...")
        registered = False
        return
    print("Queue name:", message.queue_name)
    print("Consumer name:", message.consumer_name)

connection = oracledb.connect(sample_env.get_main_connect_string(),
                              thin=False, events=True)
sub = connection.subscribe(namespace=oracledb.SUBSCR_NAMESPACE_AQ,
                           name="DEMO_BOOK_QUEUE", callback=process_messages,
                           timeout=300)
print("Subscription:", sub)
print("--> Connection:", sub.connection)
print("--> Callback:", sub.callback)
print("--> Namespace:", sub.namespace)
print("--> Protocol:", sub.protocol)
print("--> Timeout:", sub.timeout)

while registered:
    print("Waiting for notifications....")
    time.sleep(5)
