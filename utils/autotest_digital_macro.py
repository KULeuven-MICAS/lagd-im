# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Author: Jiacong Sun <jiacong.sun@kuleuven.be>
#
# Module description:
# Autotest script for digital macro unit testbench.

import re
import os
import itertools
import tqdm
import time
from pathlib import Path


def simulate_digital_macro_tb(
        log_file: str,
        show_terminal_output: bool,
        DataFromFile: int = 1,
        EnComparison: int = 1,
        EnableFlipDetection: int = 1,
        FlipDisable: int = 1,
        EnableAnalogLoop: int = 1,
        MultiCmptModeEn: int = 1,
        ) -> str:
    command = [
        "./ci/ut-run.sh",
        "--test=digital_macro",
        "--clean",
        f"--defines=\"DataFromFile={DataFromFile} EnComparison={EnComparison} "
        f"EnableFlipDetection={EnableFlipDetection} FlipDisable={FlipDisable} "
        f"EnableAnalogLoop={EnableAnalogLoop} MultiCmptModeEn={MultiCmptModeEn}\"",
        ]
    if show_terminal_output:
        print(f"Running command: {' '.join(command)} 2>&1 | tee {log_file}")
        os.system(f"{' '.join(command)} 2>&1 | tee {log_file}")
    else:
        os.system(f"{' '.join(command)} 2>&1 > {log_file}")
    return ' '.join(command)


def fetch_scoreboard_in_log(log_file: str) -> tuple[int, int, int]:
    with open(log_file, "r") as file:
        log_content = file.read()

    start_search_pattern = (
        r".*Note: \$finish"
    )

    scoreboard_pattern = (
        r"# Errors: (\d+), Warnings: (\d+)"
    )
    start_search = False
    for line in log_content.splitlines():
        if re.search(start_search_pattern, line):
            start_search = True
            continue
        if start_search:
            match = re.search(scoreboard_pattern, line)
            if match:
                errors = int(match.group(1))
                warnings = int(match.group(2))
                total_tests = 1  # one test case per log file
                if errors + warnings > 0:
                    error_case = True
                    tests_passed = 0
                    tests_failed = 1
                else:
                    error_case = False
                    tests_passed = 1
                    tests_failed = 0
                return tests_passed, total_tests, tests_failed, error_case
    if (start_search is False):
        raise ValueError(
            f"start_search is False for logfile {log_file}."
            f" Please ensure the .vcd file is not opened in VSCode or other software,"
            f" which can cause the simulation to fail"
        )
    else:
        raise ValueError(f"Scoreboard information not found in logfile {log_file}.")


if __name__ == "__main__":
    tb_file_path = "hw/unit_tests/digital_macro/tb_digital_macro.sv"
    log_folder = "results"
    show_terminal_output = False
    msg_verbose = False
    Path(log_folder).mkdir(parents=True, exist_ok=True)

    #############################
    # Define parameter pools
    DataFromFile_pool = [0, 1]
    EnComparison_pool = [0, 1]
    EnableFlipDetection_pool = [0, 1]
    FlipDisable_pool = [0, 1]
    EnableAnalogLoop_pool = [0, 1]
    MULTI_CMPT_MODE_EN_pool = [0, 1]
    #############################

    msg_pool = []
    total_cases = (
        len(DataFromFile_pool)
        * len(EnComparison_pool)
        * len(EnableFlipDetection_pool)
        * len(FlipDisable_pool)
        * len(EnableAnalogLoop_pool)
        * len(MULTI_CMPT_MODE_EN_pool)
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
        DataFromFile,
        EnComparison,
        EnableFlipDetection,
        FlipDisable,
        EnableAnalogLoop,
        MultiCmptModeEn,
    ) in itertools.product(
        DataFromFile_pool,
        EnComparison_pool,
        EnableFlipDetection_pool,
        FlipDisable_pool,
        EnableAnalogLoop_pool,
        MULTI_CMPT_MODE_EN_pool,
    ):
        test_mode_for_log = str(
            f"DF{DataFromFile}_EC{EnComparison}_EFD{EnableFlipDetection}"
            f"_FD{FlipDisable}_EAL{EnableAnalogLoop}_MCM{MultiCmptModeEn}"
        )
        log_file_path = (
            f"{log_folder}/autotest_digital_macro_{test_mode_for_log}.log"
        )

        command = simulate_digital_macro_tb(
            log_file=log_file_path,
            show_terminal_output=show_terminal_output,
            DataFromFile=DataFromFile,
            EnComparison=EnComparison,
            EnableFlipDetection=EnableFlipDetection,
            FlipDisable=FlipDisable,
            EnableAnalogLoop=EnableAnalogLoop,
            MultiCmptModeEn=MultiCmptModeEn,
        )

        (tests_passed, total_tests,
         tests_failed, error_case) = fetch_scoreboard_in_log(log_file_path)

        if error_case:
            if msg_verbose:
                msg = (
                    f"Error, case: DataFromFile={DataFromFile}, "
                    f"EnComparison={EnComparison}, EnableFlipDetection={EnableFlipDetection}, "
                    f"FlipDisable={FlipDisable}, EnableAnalogLoop={EnableAnalogLoop},"
                    f"MultiCmptModeEn={MultiCmptModeEn}. "
                    f"Scoreboard: {tests_passed}/{total_tests} correct, "
                    f"{tests_failed}/{total_tests} errors. "
                    f"Check log file: {log_file_path}"
                )
            else:
                msg = (
                    f"Error, command: {command}, "
                    f"Check log file: {log_file_path}"
                )
            error_cases += 1
            msg_pool.append(msg)
        else:
            pass_cases += 1

        pbar.update(1)
        pbar.set_description(
            f"Running autotests: [Pass: {pass_cases}/{total_cases}, "
            f"Error: {error_cases}/{total_cases}]"
        )
        time.sleep(0.1)  # To ensure tqdm display updates properly
    pbar.close()
    end_time = time.time()
    total_time = end_time - start_time
    elapsed_time = total_time / total_cases

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
        f"Average time per case: {elapsed_time/60:.2f} minutes"
    )
    print("-" * 50)
