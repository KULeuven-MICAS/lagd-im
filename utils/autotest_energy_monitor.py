# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Jiacong Sun <jiacong.sun@kuleuven.be>
#
# Module description:
# Autotest script for energy monitor unit testbench.

import re
import os
import itertools
import tqdm
import time
from pathlib import Path


def simulate_energy_monitor_tb(
        log_file: str,
        show_terminal_output: bool,
        test_mode: str = "'b110",
        num_tests: int = 100,
        pipesintf: int = 1,
        pipesmid: int = 1,
        ) -> None:
    command = [
        "./ci/ut-run.sh",
        "--test=energy_monitor",
        "--clean",
        f"--defines=\"test_mode={test_mode} NUM_TESTS={num_tests} "
        f"PIPESINTF={pipesintf} PIPESMID={pipesmid}\"",
        ]
    if show_terminal_output:
        print(f"Running command: {' '.join(command)} 2>&1 | tee {log_file}")
        os.system(f"{' '.join(command)} 2>&1 | tee {log_file}")
    else:
        os.system(f"{' '.join(command)} 2>&1 > {log_file}")


def fetch_scoreboard_in_log(log_file: str) -> tuple[int, int, int]:
    with open(log_file, "r") as file:
        log_content = file.read()

    scoreboard_pattern = (
        r"#\s*Scoreboard(?:\s*\[.*?\])?:\s*(\d+)/(\d+)\s+correct,\s*(\d+)/\d+\s+errors"
    )
    match = re.search(scoreboard_pattern, log_content)
    if match:
        tests_passed = int(match.group(1))
        total_tests = int(match.group(2))
        tests_failed = int(match.group(3))
        assert tests_passed + tests_failed == total_tests
        if tests_failed > 0:
            error_case = True
        else:
            error_case = False
        return tests_passed, total_tests, tests_failed, error_case
    else:
        raise ValueError("Scoreboard information not found in log.")


if __name__ == "__main__":
    tb_file_path = "hw/unit_tests/energy_monitor/tb_energy_monitor.sv"
    log_folder = "results"
    show_terminal_output = False
    Path(log_folder).mkdir(parents=True, exist_ok=True)

    #############################
    # Define parameter pools
    test_mode_pool = [
        "'b000",
        "'b001",
        "'b010",
        "'b011",
        "'b100",
        "'b101",
        "'b110",
    ]
    pipesintf_pool = [1]
    pipesmid_pool = [1]
    num_tests_pool = [100]
    random_test_num = 100
    #############################

    msg_pool = []
    total_cases = (
        len(test_mode_pool)
        * len(pipesintf_pool)
        * len(pipesmid_pool)
        * len(num_tests_pool)
    )
    error_cases = 0
    pass_cases = 0
    desc_msg = f"Running autotests: [Pass: {pass_cases}/{total_cases}, "
    f"Error: {error_cases}/{total_cases}]"
    pbar = tqdm.tqdm(
        total=total_cases,
        desc=desc_msg,
        ascii=True,
    )
    start_time = time.time()
    for (
        test_mode,
        pipesintf,
        pipesmid,
        num_tests,
    ) in itertools.product(
        test_mode_pool,
        pipesintf_pool,
        pipesmid_pool,
        num_tests_pool,
    ):
        test_mode_for_log = test_mode.lstrip("'b")
        log_file_path = (
            f"{log_folder}/autotest_energy_monitor_{test_mode_for_log}"
            f"_PI{pipesintf}_PM{pipesmid}.log"
        )

        simulate_energy_monitor_tb(
            log_file=log_file_path,
            show_terminal_output=show_terminal_output,
            test_mode=test_mode,
            pipesintf=pipesintf,
            pipesmid=pipesmid,
            num_tests=num_tests,
        )

        (tests_passed, total_tests,
         tests_failed, error_case) = fetch_scoreboard_in_log(log_file_path)

        if error_case:
            msg = (
                f"Error, case: Test Mode={test_mode}, "
                f"PIPESINTF={pipesintf}, PIPESMID={pipesmid}. "
                f"Scoreboard: {tests_passed}/{total_tests} correct, "
                f"{tests_failed}/{total_tests} errors. "
                f"Check log file: {log_file_path}"
            )
            error_cases += 1
        else:
            msg = (
                f"Passed, case: Test Mode={test_mode}, "
                f"PIPESINTF={pipesintf}, PIPESMID={pipesmid}. "
                f"Scoreboard: {tests_passed}/{total_tests} correct, "
                f"{tests_failed}/{total_tests} errors."
            )
            pass_cases += 1
        msg_pool.append(msg)
        pbar.update(1)
        pbar.set_description(
            f"Running autotests: [Pass: {pass_cases}/{total_cases}, "
            f"Error: {error_cases}/{total_cases}]"
        )
        time.sleep(0.1)  # To ensure tqdm display updates properly
    pbar.close()
    end_time = time.time()
    total_time = end_time - start_time
    elapese_time = total_time / total_cases

    # Summary of results
    print("-" * 50)
    print(
        f"Summary of autotest results [Pass: {pass_cases}/{total_cases}, "
        f"Error: {error_cases}/{total_cases}]:"
    )
    for message in msg_pool:
        print(message)
    print(
        f"Total time: {total_time/60:.2f} minutes, "
        f"Average time per case: {elapese_time/60:.2f} minutes"
    )
    print("-" * 50)
