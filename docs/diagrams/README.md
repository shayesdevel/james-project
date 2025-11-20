# Authentication Flow Diagrams

This directory contains visual representations of the authentication and authorization flows in the james-project system.

## Overview

The diagrams illustrate two key states:
- **Current State**: The existing authentication flow (with identified problems)
- **Target State**: The proposed improved authentication architecture

## How to Read These Diagrams

### Diagram Types

- **Flowcharts (Flowchart TD)**: Show decision logic and sequential flows with conditional branching
- **Sequence Diagrams**: Show interaction between components over time
- **Block Diagrams**: Show component relationships and data flow

### Diagram Elements

- **Rectangles**: Components or services
- **Diamonds**: Decision points (yes/no branches)
- **Arrows**: Data flow or process flow
- **Subgraphs**: Logical grouping of related components
- **Color coding**: Different colors indicate different component categories (frontend, gateway, identity, services)

### Key Components in These Diagrams

- **React UI**: Client-side application
- **Kong API Gateway**: API routing, token validation, and authorization
- **Keycloak**: Identity provider (IdP) for authentication
- **Spring Boot Microservices**: Backend services handling business logic
- **User Groups**: Organizational grouping mechanism
- **Roles**: Fine-grained access control units

## Current State Diagrams

Located in `current-state/`:

### 1. Current Authentication Flow (`current-auth-flow.md`)
Shows the complete authentication and authorization flow as it currently exists, including:
- User login through React UI
- Token generation by Keycloak
- Kong's validation and routing
- Role checking at multiple layers
- Service-level access decisions

**Problem Area**: The flow shows how users accumulate excessive roles and permissions.

### 2. Problem Illustration (`problem-illustration.md`)
Illustrates the over-permissioning problem visually by showing:
- How meaningless group assignments cascade
- The multiplication effect of service-level roles
- Typical permission blast radius (1 user → 15+ service roles)
- Security implications

## Target State Diagrams

Located in `target-state/`:

### 1. Simple User Journey (`simple-user-journey.md`) - **Phase 1 Focus**

Shows the complete user journey through the new simplified authorization model:
- User login via React UI
- Group-to-role assignment in Keycloak
- Token generation with business role
- Kong validation and routing
- Spring Security role checking at service level
- Access grant/deny decision

**Key Design**: Direct service-level mapping with single business role per user context. Simplified and secure.

### 2. Business Role Hierarchy (`role-hierarchy.md`) - **Architecture Blueprint**

Shows the hierarchical organization of business roles and user groups:
- Three user groups: External Users, Internal Users, Services
- Four business roles: User, Manager, Admin, Service
- Role escalation paths and inheritance patterns
- Role definitions and capabilities
- Concrete assignment examples
- Group-to-role mapping rules

**Key Design**: Clear organizational structure with single role per user context. Group membership determines assignable roles.

### 3. Permission Resolution Flow (`permission-resolution.md`) - **Decision Logic**

Shows how role-based access decisions are made at the service level:
- Token extraction and validation
- Role extraction from JWT claims
- Service-level permission decisions
- Allow/deny decision points with examples
- Role-to-service access matrix
- Phase 1 vs Phase 2 comparison

**Key Design**: Service-level checks with clear decision flow. Phase 1 focuses on service granularity; Phase 2 adds controller-level rules.

### 4. JWT Token Structure (`keycloak-token-structure.md`) - **Implementation Detail**

Shows the significant simplification in token structure between old and new models:
- Current state: Bloated tokens with 14+ service roles
- Target state: Simplified tokens with 1 business role
- 85% token size reduction
- Keycloak configuration changes
- Spring Security extraction logic
- Network and performance benefits

**Key Design**: Cleaner tokens = cleaner permissions. Target tokens are 6x smaller with better security posture.

### Future Diagrams (Phase 2+)

Additional diagrams will show enhanced authentication features:
- Controller-level permission granularity
- Attribute-based access control (ABAC) rules
- Fine-grained endpoint-level access control
- Time-based and context-aware authorization

## Usage

These diagrams are best viewed in:
- GitHub's native Markdown renderer (renders Mermaid diagrams natively)
- Mermaid Live Editor: https://mermaid.live/
- VSCode with Mermaid extension

## Updates & Maintenance

When authentication architecture changes:
1. Update the relevant diagram file
2. Update the description in this README
3. Add a note about what changed and why

