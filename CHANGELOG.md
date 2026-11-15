# Changelog

## v1.1 — 5 Nov 2026

### Added
- Case study 01, *Popular isn't loved*: SQL C01–C04, results (KPI benchmark, price × format, chain brands, priority list), README and dashboard screenshot.

## v1.0 — 4 Nov 2026

First release as a standalone repo (moved out of `sql-business-problems`).

### Added
- Original BigQuery console scripts, kept verbatim in `sql/00_source/` for traceability.
- Column-level profiling scripts `00`–`12`.
- Cleaning layer: preview and `CREATE restaurants_clean`.
- Validation: clean-table checks and restaurant-grain reconciliation (51,717 listings → 12,453 restaurants).
- Business analysis A01–A08 at restaurant grain, with results as CSV.
- Docs: data dictionary, data-quality log, query review log, tracker workbook.
- README banner.

## Repository maintenance

- 9 Nov 2026: `.gitattributes` for SQL and HTML files; README status marked complete.
- 14 Nov 2026: README restored and stray `solution.sql` removed after an unrelated upload on 12 Nov overwrote them.
- 15 Nov 2026: added this changelog.
