#------------------------------------------------------------------------------
# Copyright (c) 2019, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# SetupSamples.py
#
# Creates users and populates their schemas with the tables and packages
# necessary for the samples. An edition is also created for the demonstration
# of PL/SQL editioning.
#------------------------------------------------------------------------------

import asyncio
import sample_env

loop = asyncio.get_event_loop()
loop.run_until_complete(sample_env.create_samples())
loop.close()
print("Done.")
