# Repository Guidelines

## Project Structure

- `project-context/` contains assignment prompts, example projects, research references, and earlier course check-ins.
- `current-status/` contains the latest annotated project check-ins. Treat these as the current project record and consult them before changing the research plan.
- This repository currently has no source-code, test, or build directories. Add new analysis, data, figures, and write-ups in clearly named folders as the visualization work develops; keep source data distinct from derived outputs.

## Build, Development, and Validation

There is no configured build command, dependency manifest, or automated test suite. Do not assume a particular language or toolchain. Document the steps needed to regenerate any analysis or figure alongside the relevant deliverable. Before sharing a visualization, check that its labels, units, sample, time period, and data source are clear, and that its values agree with the underlying data.

## Style and Naming

Use descriptive, consistent filenames. For example, name figures `figure-01-major-participation-by-year.png` and dated project notes `YYYY-MM-DD-topic.md`. Keep figure titles, axis labels, legends, and source notes readable and consistent across the set. If analysis code is introduced, follow the conventions and formatter of the selected language or tool; avoid adding formatting tools without a project need.

## Testing and Review

No automated tests are configured. Validate changes by reproducing affected figures or tables from the stated inputs, checking calculations and missing observations, and reviewing the rendered output at its intended size. Explain any data limitations that affect interpretation.

## Commits and Pull Requests

No repository-specific commit convention or PR workflow is documented. Use short, imperative commit subjects, such as `Add major participation trend figure`. A pull request should summarize the research or visualization change, identify data sources and reproduction steps, note relevant limitations, and include figure previews when visuals change.
