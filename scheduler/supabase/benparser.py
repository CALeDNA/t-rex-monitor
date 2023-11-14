import os
import json

QUEUES=["/etc/ben/queue/qc.ini", "/etc/ben/queue/assign.ini", "/etc/ben/queue/ecopcr.ini", "/etc/ben/queue/blast.ini", "/etc/ben/queue/ac.ini", "/etc/ben/queue/newick.ini", "/etc/ben/queue/tronko.ini"]
OUTDIR="/etc/ben/json"
for queue in QUEUES:
    jobs = []
    job = {}

    queuename = os.path.basename(queue).split(".")[0]
    with open(queue, 'r') as ini:
        for line in ini:
            if line.strip() == "[job]":
                jobs.append(job)
                job = {}
            else:
                key = line.split(" = ")[0].strip()
                value = line.split(" = ")[1].strip()
                job[key] = value

    # Filter out empty dictionaries
    jobs = [d for d in jobs if d]

    with open(os.path.join(OUTDIR, f"{queuename}.json"), 'w') as out:
        json.dump(jobs, out)
