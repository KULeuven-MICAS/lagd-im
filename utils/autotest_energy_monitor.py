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


def update_tb_energy_monitor(file_path: str, parameter_dict: dict) -> None:
    with open(file_path, 'r') as file:
        content = file.read()

    # Update test_mode parameter
    if "test_mode" in parameter_dict.keys():
        content = re.sub(r'localparam int test_mode = `\w+;',
                         f'localparam int test_mode = `{parameter_dict["test_mode"]};', content)

    # Update LITTLE_ENDIAN parameter
    if "LITTLE_ENDIAN" in parameter_dict.keys():
        content = re.sub(r'localparam int LITTLE_ENDIAN = `\w+;',
                         f'localparam int LITTLE_ENDIAN = `{parameter_dict["LITTLE_ENDIAN"]};', content)

    # Update PARALLELISM parameter
    if "PARALLELISM" in parameter_dict.keys():
        content = re.sub(r'localparam int PARALLELISM = \d+;',
                         f'localparam int PARALLELISM = {parameter_dict["PARALLELISM"]};', content)

    # Update PIPESINTF parameter
    if "PIPESINTF" in parameter_dict.keys():
        content = re.sub(r'localparam int PIPESINTF = \d+;',
                         f'localparam int PIPESINTF = {parameter_dict["PIPESINTF"]};', content)

    # Update PIPESMID parameter
    if "PIPESMID" in parameter_dict.keys():
        content = re.sub(r'localparam int PIPESMID = \d+;',
                         f'localparam int PIPESMID = {parameter_dict["PIPESMID"]};', content)

    # Update NUM_TESTS parameter
    if "NUM_TESTS" in parameter_dict.keys():
        content = re.sub(r'localparam int NUM_TESTS = \d+;',
                         f'localparam int NUM_TESTS = {parameter_dict["NUM_TESTS"]};', content)

    with open(file_path, 'w') as file:
        file.write(content)


def simulate_energy_monitor_tb(log_file: str, show_terminal_output: bool) -> None:
    if show_terminal_output:
        os.system(f"./ci/ut-run.sh --test=energy_monitor --clean 2>&1 | tee {log_file}")
    else:
        os.system(f"./ci/ut-run.sh --test=energy_monitor --clean 2>&1 > {log_file}")


def check_error_in_log(log_file: str) -> bool:
    with open(log_file, 'r') as file:
        log_content = file.read()

    error_patterns = [
        r'Error:',
        r'Fatal:',
        r'Simulation failed',
        r'Assertion failed'
    ]

    for pattern in error_patterns:
        if re.search(pattern, log_content):
            return True
    return False


def fetch_scoreboard_in_log(log_file: str) -> tuple[int, int, int]:
    with open(log_file, 'r') as file:
        log_content = file.read()

    scoreboard_pattern = r"#\s*Scoreboard(?:\s*\[.*?\])?:\s*(\d+)/(\d+)\s+correct,\s*(\d+)/\d+\s+errors"
    match = re.search(scoreboard_pattern, log_content)
    if match:
        tests_passed = int(match.group(1))
        total_tests = int(match.group(2))
        tests_failed = int(match.group(3))
        return tests_passed, total_tests, tests_failed
    else:
        raise ValueError("Scoreboard information not found in log.")


if __name__ == "__main__":
    tb_file_path = "hw/unit_tests/energy_monitor/tb_energy_monitor.sv"
    log_folder = "results"
    show_terminal_output = False
    Path(log_folder).mkdir(parents=True, exist_ok=True)

    #############################
    # Define parameter pools
    test_mode_pool = ["S1W1H1_TEST",
                      "S0W1H1_TEST",
                      "S0W0H0_TEST",
                      "S1W0H0_TEST",
                      "MaxPosValue_TEST",
                      "MaxNegValue_TEST",
                      "RANDOM_TEST"]
    endian_pool = ["True", "False"]
    parallelism_pool = [1, 4]
    pipesintf_pool = [0, 1, 2]
    pipesmid_pool = [0, 1, 2, 8]
    num_tests_pool = [100]
    random_test_num = 1000000
    #############################

    msg_pool = []
    total_cases = (
    len(test_mode_pool) * len(endian_pool) * len(parallelism_pool) *
    len(pipesintf_pool) * len(pipesmid_pool) * len(num_tests_pool))
    error_cases = 0
    pass_cases = 0
    pbar = tqdm.tqdm(total=total_cases,
                     desc=f"Running autotests: [Pass: {pass_cases}/{total_cases}, Error: {error_cases}/{total_cases}]",
                     ascii=True)
    start_time = time.time()
    for test_mode, endian, parallelism, pipesintf, pipesmid, num_tests in itertools.product(
        test_mode_pool,
        endian_pool,
        parallelism_pool,
        pipesintf_pool,
        pipesmid_pool,
        num_tests_pool
    ):
        log_file_path = f"{log_folder}/autotest_energy_monitor_{test_mode}_PE{parallelism}_LE{endian}" \
                f"_PI{pipesintf}_PM{pipesmid}.log"
        log_file_path = f"{log_folder}/autotest_energy_monitor_{test_mode}_PE{parallelism}_LE{endian}" \
                f"_PI{pipesintf}_PM{pipesmid}.log"

        parameters_to_update = {
            "test_mode": test_mode,
            "LITTLE_ENDIAN": endian,
            "PARALLELISM": parallelism,
            "PIPESINTF": pipesintf,
            "PIPESMID": pipesmid,
            "NUM_TESTS": num_tests if test_mode != "RANDOM_TEST" else random_test_num
        }

        update_tb_energy_monitor(tb_file_path, parameters_to_update)
        simulate_energy_monitor_tb(log_file_path, show_terminal_output=show_terminal_output)

        tests_passed, total_tests, tests_failed = fetch_scoreboard_in_log(log_file_path)

        if check_error_in_log(log_file_path):
            msg = f"Error, case: Test Mode={test_mode}, PARALLELISM={parallelism}, " \
                f"LITTLE_ENDIAN={endian}, PIPESINTF={pipesintf}, PIPESMID={pipesmid}. " \
                f"Scoreboard: {tests_passed}/{total_tests} correct, {tests_failed}/{total_tests} errors. " \
                f"Check log file: {log_file_path}"
            error_cases += 1
        else:
            msg = f"Passed, case: Test Mode={test_mode}, PARALLELISM={parallelism}, " \
                f"LITTLE_ENDIAN={endian}, PIPESINTF={pipesintf}, PIPESMID={pipesmid}. " \
                f"Scoreboard: {tests_passed}/{total_tests} correct, {tests_failed}/{total_tests} errors."
            pass_cases += 1
        msg_pool.append(msg)
        pbar.update(1)
        pbar.set_description(
            f"Running autotests: [Pass: {pass_cases}/{total_cases}, Error: {error_cases}/{total_cases}]"
            )
        time.sleep(0.1)  # To ensure tqdm display updates properly
    pbar.close()
    end_time = time.time()
    total_time = end_time - start_time
    elapese_time = total_time / total_cases

    # Summary of results
    print("-" * 50)
    print(
        f"Summary of autotest results [Pass: {pass_cases}/{total_cases}, Error: {error_cases}/{total_cases}]:"
        )
    for message in msg_pool:
        print(message)
    print(f"Total time: {total_time/60:.2f} minutes, Average time per case: {elapese_time/60:.2f} minutes")
    print("-" * 50)
