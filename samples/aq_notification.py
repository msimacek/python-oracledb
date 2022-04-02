#------------------------------------------------------------------------------
# Copyright (c) 2018, 2022, Oracle and/or its affiliates.
# This program is free software: you can modify it and/or redistribute it
# under the terms of:
#
# (i)  the Universal Permissive License v 1.0 or at your option, any
#      later version (http://oss.oracle.com/licenses/upl); and/or
#
# (ii) the Apache License v 2.0. (http://www.apache.org/licenses/LICENSE-2.0)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# aq_notification.py
#
# Demonstrates using advanced queuing notification. Once this script is
# running, use another session to enqueue a few messages to the
# "DEMO_BOOK_QUEUE" queue. This is most easily accomplished by running the
# object_aq.py sample.
#------------------------------------------------------------------------------

import time

import oracledb
import sample_env

# this script is currently only supported in python-oracledb thick mode
oracledb.init_oracle_client()

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
                              events=True)
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
