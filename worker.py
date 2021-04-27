#!/usr/bin/env python

import time
import rediswq

host="redis"
# Uncomment next two lines if you do not have Kube-DNS working.
import os
#host = os.getenv("REDIS_SERVICE_HOST")

q = rediswq.RedisWQ(name="job2", host="redis")
print("Worker with sessionID: " +  q.sessionID())
print("Initial queue state: empty=" + str(q.empty()))
while not q.empty():
  item = q.lease(lease_secs=10, block=True, timeout=2)
  if item is not None:
    itemstr = item.decode("utf-8")
    print("Working on " + itemstr)
    os.system("conda run --no-capture-output -n myenv bash ./pipeline/assemble/02_plasmidspades.sh %(ARRAY_ID)s %(CPU)s %(MEM)s" % {'ARRAY_ID':itemstr,'CPU':16,'MEM':16})
    q.complete(item)
  else:
    print("Waiting for work")
print("Queue empty, exiting")
