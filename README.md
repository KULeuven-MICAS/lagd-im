
# LAGD Ising RTL

=============================

This repository is for the hardware implementation of the Ising LAGD chip.

## Getting the sources

To download, run the following code:

   $ git clone --recursive `git@github.com:KULeuven-MICAS/lagd-im.git`

**Warning**: git clone takes around 1.2 GB of disk and download size

## Third-party libraries

1. [Cheshire](https://github.com/pulp-platform/cheshire) - Pulp Cheshire SoC V0.3.1 (tag=v0.3.1-1-g3d9aefb)

## GitHub Actions list

### Linting

1. License check (pulp-platform/pulp-actions/lint-license@v2.4.1)
2. Verible lint (chipsalliance/verible-linter-action@main)
   - Verible version: v0.0-4017-g62aee204
3. Yaml lint (ibiqlik/action-yamllint@v3)
4. Python lint (py-actions/flake8@v2)
   - Python version: 3.11
   - Flake8 version: 6.0.0
5. Clang-format check (DoozyX/clang-format-lint-action@v0.16.2)
   - Clang-format version: 14
6. EditorConfig check (editorconfig-checker/action-editorconfig-checker@main)
7. TCL lint
    - Tclint version 0.4.2
