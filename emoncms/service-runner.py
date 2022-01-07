#!/usr/bin/env python3

## Used to run arbitrary commands from the EmonCMS web interface
# EmonCMS submits commands to redis where this service picks them up
# Used in conjunction with:
# - Admin module to run service-runner-update.sh
# - Backup module
# - Others??

import subprocess
import time
import shlex
import redis
import os
import logging

KEYS = ["service-runner", "emoncms:service-runner"]


def connect_redis():
    while True:
        try:
            server = redis.Redis(
                host=os.getenv('REDIS_HOST'),
                port=os.getenv('REDIS_PORT'),
            )
            if server.ping():
                logging.info("Connected to redis server", flush=True)
                return server
        except redis.exceptions.ConnectionError:
            logging.error("Unable to connect to redis server, sleeping for 30s", flush=True)
        time.sleep(30)


def main():
    if not os.getenv('REDIS_ENABLED'):
        logging.warn("Redis is disabled. Won't start runner.")
        return

    logging.info("Starting service-runner", flush=True)
    server = connect_redis()
    while True:
        try:
            # Get the next item from the 'service-runner' list, blocking until one exists
            packed = server.blpop(KEYS)
            if not packed:
                continue
            flag = packed[1].decode()
        except redis.exceptions.ConnectionError:
            logging.error("Connection to redis server lost, attempting to reconnect", flush=True)
            server = connect_redis()
            continue

        logging.info("Got flag:", flag, flush=True)
        if ">" in flag:
            script, logfile = flag.split(">")
            logging.info("STARTING:", script, '&>', logfile, flush=True)
            # Got a cmdline, now run it.
            with open(logfile, "w") as f:
                try:
                    subprocess.call(shlex.split(script), stdout=f, stderr=f)
                except Exception as exc:
                    # If an error occurs running the subprocess, add the error to
                    # the specified logfile
                    f.write("Error running [%s]" % script)
                    f.write("Exception occurred: %s" % exc)
                    continue
        else:
            script = flag
            logging.info("STARTING:", script, flush=True)
            try:
                subprocess.call(shlex.split(script), stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
            except Exception as exc:
                continue

        logging.info("COMPLETE:", script, flush=True)


if __name__ == "__main__":
    main()
