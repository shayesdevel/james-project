# Authentication & Authorization Documentation

This directory contains comprehensive documentation about the authentication and authorization architecture for the James project.

## Overview

The James project is a microservices-based system built with:
- **Backend**: Spring Boot 3.5 (15+ microservices)
- **Frontend**: React UI
- **Identity Provider**: Keycloak
- **API Gateway**: Kong

This documentation captures the current state of authentication/authorization, identifies critical issues, and will guide the redesign toward a secure, scalable solution.

## Documentation Structure

### 01-current-state/
Documents the existing (broken) authentication and authorization implementation.

**Files**:
- **[keycloak-overview.md](./01-current-state/keycloak-overview.md)**: How Keycloak is currently configured, including group assignments and role mappings
- **[broken-authorization.md](./01-current-state/broken-authorization.md)**: Detailed explanation of the over-permissioning catastrophe and security implications
- **[group-based-issues.md](./01-current-state/group-based-issues.md)**: Technical breakdown of why the group-based approach fails at scale

### 02-target-design/ (Coming Soon)
Will document the proposed secure authorization architecture.

### 03-migration-plan/ (Coming Soon)
Will outline the transition strategy from current state to target design.

## The Core Problem

**TL;DR**: Authenticated users receive far too many Keycloak roles due to automatic group assignments, creating catastrophic over-permissioning across 15+ microservices.

### Why This Matters

- **Security Risk**: Users have access to resources they shouldn't
- **Compliance Impact**: Violates principle of least privilege
- **Audit Nightmare**: Cannot trace who should have access to what
- **Scalability**: Breaks down as microservices grow
- **Maintenance**: No clear ownership of permission boundaries

## Quick Navigation

### For New Readers
Start here to understand the problem:
1. [Keycloak Overview](./01-current-state/keycloak-overview.md) - Understand current setup
2. [Broken Authorization](./01-current-state/broken-authorization.md) - See what's wrong
3. [Group-Based Issues](./01-current-state/group-based-issues.md) - Understand why it fails

### For Technical Implementers
Jump to specific concerns:
- Role assignment mechanism: [keycloak-overview.md](./01-current-state/keycloak-overview.md)
- Security implications: [broken-authorization.md](./01-current-state/broken-authorization.md)
- Spring Security integration: [group-based-issues.md](./01-current-state/group-based-issues.md)

### For Decision Makers
Key insights:
- [Broken Authorization](./01-current-state/broken-authorization.md) - Security catastrophe
- [Group-Based Issues](./01-current-state/group-based-issues.md) - Why this doesn't scale

## Related Resources

- **GitHub Issue**: [#1 - Document current broken Keycloak authorization state](https://github.com/shayesdevel/james-project/issues/1)
- **Framework**: cognitive-framework v2.2
- **Project Root**: [CLAUDE.md](../../CLAUDE.md)

## Status

**Last Updated**: 2025-11-20
**Documentation Phase**: Current State Analysis
**Next Phase**: Target Design (pending completion of current state docs)

## Contributing

This documentation is maintained by the Scribe Agent as part of the authentication spike. Updates should follow:
1. Document factual observations about current state
2. Be clear about what is known vs. needs investigation
3. Provide concrete examples where possible
4. Link to related issues and decisions
