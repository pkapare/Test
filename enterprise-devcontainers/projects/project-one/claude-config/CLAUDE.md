# Project: OpenClaw Enterprise — Multi-Agent AI Orchestration Platform

## Domain Context
OpenClaw Enterprise is an Agent Experience Platform (AEP) built on the open-source OpenClaw framework. It provides multi-agent orchestration for enterprise AI workloads with BYO (Bring Your Own) pluggable adapters for LLM providers, vector stores, and tool registries.

## Architecture
- Microsoft Agent Framework for agent lifecycle management
- Clean Architecture with hexagonal ports-and-adapters
- CQRS via MediatR for command/query separation
- MassTransit for inter-agent async messaging
- Blazor/MudBlazor for the orchestration dashboard

## Key Components
- Agent Registry (register, version, deploy agents)
- Orchestration Engine (multi-agent workflow DAGs)
- Tool Registry (MCP server management, tool approval workflow)
- Guardrails Engine (input/output filtering, PII detection)
- Observability Hub (token usage, latency, cost tracking)

## BYO Adapters
All infrastructure is pluggable via adapter interfaces:
- ILlmProvider → Anthropic, OpenAI, Azure OpenAI, Ollama
- IVectorStore → Qdrant, Pinecone, pgvector, Weaviate
- IToolRegistry → MCP, LangChain, custom
- IGuardrail → Anthropic Constitutional AI, custom rules
