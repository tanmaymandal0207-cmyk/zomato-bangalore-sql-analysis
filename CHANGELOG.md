# Changelog

## Unreleased

### Docs

- README: LinkedIn link added to the author line (20 Nov 2026).

## v1.3 — 19 Nov 2026

### Added

- Seven small business problems, each committed on its own (query, then result), run in BigQuery on 19 Nov 2026:
  - A13 Most-liked dishes
  - A14 Listing categories
  - A15 Affordable quality by locality
  - A16 New restaurants by locality
  - A17 Cuisine price positioning
  - A18 Hero restaurants by locality
  - A19 Online-ordering onboarding targets

### Changed

- README: A13–A19 in business questions, a problem → answer → action table, limitations.
- Query review log: execution dates for A13–A19.
- Banner: 19 business questions.

## v1.2 — 18 Nov 2026

### Added

- A09 Pareto test by locality: 14.8% of restaurants hold 80% of votes city-wide; 29 of 53 localities (50+ restaurants) beat 80/20.
- A10 Table booking vs rating: +0.54 overall, +0.36 with price held constant.
- A11 Supply gaps: locality × price band cells with more votes per restaurant than expected.
- A12 Chains vs independents, overall and by format.
- Results for A09–A12, run in BigQuery on 18 Nov 2026.

### Changed

- README: key findings 7–10, business questions A09–A12, A10 and A12 result tables, limitations.
- Query review log: A09 entry (original Q9 attempt and its fixes).
- Data dictionary: `price_band`, `format`, chain flag and `demand_index`.
- Banner: 12 business questions.

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
- 16 Nov 2026: README links the changelog and related projects; repository tree lists `CHANGELOG.md`.
- 17 Nov 2026: Markdown formatting pass (markdownlint): code fences tagged with a language, blank lines around headings and lists. No content changes.
