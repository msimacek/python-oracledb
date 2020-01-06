#------------------------------------------------------------------------------
# Copyright (c) 2019, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# DropSamples.py
#
# Drops the database objects used for the samples.
#------------------------------------------------------------------------------

import asyncio
import sample_env

loop = asyncio.get_event_loop()
loop.run_until_complete(sample_env.drop_samples())
loop.close()
print("Done.")
