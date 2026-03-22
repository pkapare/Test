# Project: DRR Engine — Digital Regulatory Reporting

## Domain Context
DRR Engine automates regulatory trade reporting using the ISDA Common Domain Model (CDM). It transforms trade events into jurisdiction-specific regulatory reports, validates against CDM schemas, and manages exception workflows via multi-agent architecture.

## Architecture
- Clean Architecture with hexagonal ports-and-adapters
- ISDA CDM Java interop via RUNE DSL tooling
- CQRS for command/query separation
- Multi-agent exception management (triage, enrichment, resolution)
- EF Core with PostgreSQL for persistence

## Key Bounded Contexts
- CDM Mapping Engine (trade event → CDM object graph)
- Validation Engine (CDM schema + business rule validation)
- Report Generator (CDM → jurisdiction-specific XML/JSON reports)
- Exception Manager (multi-agent workflow for validation failures)
- Audit Trail (immutable log of all report submissions)

## Regulatory Frameworks
- EMIR (EU): Trade reporting, margin, clearing
- MiFIR (EU): Transaction reporting, transparency
- CFTC (US): Swap data reporting
- MAS (Singapore): OTC derivatives reporting
- JFSA (Japan): Trade repository reporting
- ASIC (Australia): OTC derivatives reporting

## CDM Conventions
- All trade representations MUST conform to ISDA CDM schema
- Use RUNE DSL for validation rules where possible
- CDM version pinned in Directory.Build.props
- Java interop via IKVM for CDM reference implementation
