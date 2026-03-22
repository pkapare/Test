# Project: Sentinel CDM — Trade Surveillance Platform

## Domain Context
Sentinel CDM is a trade surveillance platform targeting 270 detection models across 20 categories, 14 jurisdictions, and 12 asset classes. It competes with NICE Actimize, Nasdaq SMARTS, and similar platforms.

## Architecture
- Clean Architecture with hexagonal ports-and-adapters
- CQRS command/query separation via MediatR
- Domain events for cross-bounded-context communication
- EF Core with PostgreSQL (read replicas for query side)
- MassTransit + RabbitMQ for async processing

## Key Bounded Contexts
- Detection Engine (alert generation from market data)
- Case Management (investigation workflow)
- Regulatory Reporting (jurisdiction-specific report generation)
- Model Registry (detection model lifecycle management)

## Jurisdictions
EMIR, MiFIR, CFTC, MAS, JFSA, ASIC, FCA, SEC, HKMA, BaFin, AMF, FINMA, OSFI, SEBI

## BYO Philosophy
Zero vendor lock-in. All infrastructure components are pluggable via adapter interfaces. Configuration-over-code for infrastructure swaps.
