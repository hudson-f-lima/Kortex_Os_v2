# 1. Record architecture decisions

Date: 2026-07-13

## Status

Accepted

## Context

We need to record the architectural decisions made on this project. Without a structured format, it becomes hard for new engineers (or AI agents) to understand *why* a particular technical path was chosen, leading to repeated debates or accidental reversals of critical foundations.

## Decision

We will use Architecture Decision Records, as described by Michael Nygard. We will keep these records in the `docs/adr/` directory in the project repository. 

Each ADR will follow a simple, standardized format:
- Title
- Date
- Status
- Context
- Decision
- Consequences

## Consequences

By recording these decisions, we establish a Single Source of Truth for *why* things are built the way they are. This requires discipline from developers and AI agents to document significant shifts in database modeling, networking, security, or product scope before execution.
