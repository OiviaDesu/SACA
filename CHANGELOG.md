# Changelog

All notable changes to this repository should be documented in this file.

## Unreleased

### Added
- Split Slurm wrappers for LR and XGBoost classifier training.
- Intermediate diagnosis dataset build flow before multi-source classifier runs.
- Campaign submit helper for `quick -> balanced -> full` classifier ladders.
- Dedicated classifier tuning run log documentation.

### Changed
- Classifier trainer now supports tuning profiles, live progress logging, and
  cleaner dataset preprocessing.
- Repository documentation now includes stronger setup, safety, and release
  guidance for GitHub publication.
