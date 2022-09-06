#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Copyright 2022 - EMBL-EBI
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import time
import argparse

from subprocess import run, CalledProcessError

import logging

logging.basicConfig(level=logging.INFO)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Simple bwait wrapper that handles LSF connection issues."
    )
    parser.add_argument(
        "-w",
        dest="wait_condition",
        required=True,
        type=str,
        help="Required. Specifies the wait condition to be satisfied. This expression follows the same format as the job dependency expression for the bsub -w option",
    )
    parser.add_argument(
        "-t",
        dest="timeout",
        required=False,
        type=int,
        help="Specifies the timeout interval for the wait condition, in minutes. Specify an integer between 1 and 525600 (one year). By default, LSF uses the value of the DEFAULT_BWAIT_TIMEOUT parameter in the lsb.params file",
    )
    parser.add_argument(
        "-x",
        dest="retries",
        required=False,
        default=5,
        type=int,
        help="How many times should mwait retry if the command fails?.",
    )
    parser.add_argument(
        "-s",
        dest="sleep",
        required=False,
        default=2,
        type=int,
        help="Sleep time (seconds) between retries.",
    )

    args = parser.parse_args()

    retries = args.retries

    bwait_args = ["bwait", "-w", f"'{args.wait_condition}'"]

    if args.timeout is not None:
        bwait_args.extend(["-t", str(args.timeout)])

    attempt = 0

    while attempt < retries:
        try:
            run_output = run(" ".join(bwait_args), check=True, shell=True)
            exit(run_output.returncode)
        except CalledProcessError as exception:
            if exception.returncode == 3:
                # Job not found
                exit(exception.returncode)
            logging.exception(exception)
            attempt += 1
            logging.info(f"bwait attempt {attempt}")
            time.sleep(args.sleep)
