# JWT Token Structure - Old vs New

> **⚠️ VERIFICATION NEEDED**: Kong's exact role, positioning in request flow, and SSL/TLS handling need verification. Known issue: x.509 certificate validation in SSL handshake. Token examples shown below are based on assumed Keycloak configuration.

## Overview

This document shows the significant simplification in JWT token structure when migrating from the current over-permissioned model to the target business-role-based model. The new structure is cleaner, smaller, and provides better security posture.

---

## Token Comparison Diagram

```mermaid
graph TB
    subgraph Current["❌ Current State - Over-Permissioned"]
        direction TB

        CurHead["JWT Header"]
        CurHeadContent["<br/>typ: JWT<br/>alg: RS256<br/>kid: key-1<br/>"]

        CurPay["JWT Payload (Large)"]
        CurPayContent["<br/>sub: user123<br/>iss: keycloak<br/>aud: [srv1, srv2...]<br/>group: GroupA<br/>roles: [<br/>  'reports-reader',<br/>  'reports-writer',<br/>  'approval-viewer',<br/>  'approval-approver',<br/>  'user-admin',<br/>  'user-editor',<br/>  'settings-reader',<br/>  'settings-editor',<br/>  'audit-viewer',<br/>  'audit-exporter',<br/>  'batch-scheduler',<br/>  'batch-executor',<br/>  'integration-manager',<br/>  'integration-executor'<br/>]<br/>realm_access: {<br/>  roles: [...12 more...]<br/>}<br/>permissions: {<br/>  services: {...}<br/>  endpoints: {...}<br/>}<br/>other_claims: {...15 fields...}<br/>exp: 1700000000<br/>iat: 1699996400<br/>jti: unique-id<br/>"]

        CurSig["JWT Signature"]
        CurSigContent["<br/>[RS256 Signature Hash]<br/>"]

        CurSize["📊 Token Size<br/>~2.5 - 3.5 KB<br/>(Often compressed to 1.5 KB)"]

        CurHead --> CurHeadContent
        CurPay --> CurPayContent
        CurSig --> CurSigContent
        CurPayContent --> CurSize
    end

    subgraph Target["✅ Target State - Simplified"]
        direction TB

        TgtHead["JWT Header"]
        TgtHeadContent["<br/>typ: JWT<br/>alg: RS256<br/>kid: key-1<br/>"]

        TgtPay["JWT Payload (Small)"]
        TgtPayContent["<br/>sub: user123<br/>iss: keycloak<br/>aud: microservices<br/>group: internal<br/>business_role: Manager<br/>exp: 1700000000<br/>iat: 1699996400<br/>jti: unique-id<br/>"]

        TgtSig["JWT Signature"]
        TgtSigContent["<br/>[RS256 Signature Hash]<br/>"]

        TgtSize["📊 Token Size<br/>~400 - 600 bytes<br/>(~20% of current)"]

        TgtHead --> TgtHeadContent
        TgtPay --> TgtPayContent
        TgtSig --> TgtSigContent
        TgtPayContent --> TgtSize
    end

    subgraph Comparison["📊 Size Reduction"]
        direction TB
        OldSize["Current: ~3 KB average"]
        NewSize["Target: ~0.5 KB average"]
        Reduction["Reduction: ~85%"]
        Impact["Network/Storage Benefit:<br/>6x smaller tokens"]
    end

    Current -.->|"Migrate"| Target
    CurSize -.-> OldSize
    TgtSize -.-> NewSize
    OldSize -.-> Reduction
    NewSize -.-> Reduction
    Reduction -.-> Impact

    %% Styling
    classDef currentStyle fill:#ffebee,stroke:#c62828,stroke-width:2px,color:#000
    classDef targetStyle fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#000
    classDef contentStyle fill:#f5f5f5,stroke:#616161,stroke-width:1px,color:#000
    classDef comparisonStyle fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#000

    class Current currentStyle
    class Target targetStyle
    class CurHeadContent,CurPayContent,CurSigContent,TgtHeadContent,TgtPayContent,TgtSigContent,CurSize,TgtSize contentStyle
    class Comparison,OldSize,NewSize,Reduction,Impact comparisonStyle
```

---

## Detailed Token Structure

### Current State Token (Old Model)

#### Header
```json
{
  "typ": "JWT",
  "alg": "RS256",
  "kid": "key-1"
}
```

#### Payload (Bloated)
```json
{
  "sub": "user123",
  "name": "Jane Smith",
  "email": "jane@company.com",
  "iss": "https://keycloak.company.com/auth/realms/app-realm",
  "aud": [
    "reports-service",
    "approval-service",
    "user-service",
    "settings-service",
    "audit-service",
    "batch-service",
    "integration-service"
  ],
  "preferred_username": "jane.smith",
  "given_name": "Jane",
  "family_name": "Smith",
  "group": "GroupA",
  "roles": [
    "reports-reader",
    "reports-writer",
    "reports-admin",
    "approval-viewer",
    "approval-approver",
    "approval-auditor",
    "user-admin",
    "user-editor",
    "user-viewer",
    "settings-reader",
    "settings-editor",
    "settings-admin",
    "audit-viewer",
    "audit-exporter",
    "audit-deleter",
    "batch-scheduler",
    "batch-executor",
    "batch-admin",
    "integration-manager",
    "integration-executor"
  ],
  "realm_access": {
    "roles": [
      "manage-account",
      "manage-account-links",
      "view-profile"
    ]
  },
  "client_id": "app-client",
  "permissions": {
    "services": {
      "reports-service": ["read", "write", "admin"],
      "approval-service": ["view", "approve"],
      "user-service": ["admin", "edit"]
    },
    "endpoints": {
      "/api/reports/*": ["GET", "POST"],
      "/api/approval/*": ["GET", "POST", "PATCH"]
    }
  },
  "tenant_id": "tenant-001",
  "department": "Finance",
  "cost_center": "CC-123",
  "manager_id": "manager-456",
  "session_state": "abc123def456",
  "session_id": "session-xyz789",
  "acr": "1",
  "allowed-origins": ["https://app.company.com"],
  "realm_name": "app-realm",
  "exp": 1700000000,
  "iat": 1699996400,
  "auth_time": 1699996400,
  "jti": "abc123def456"
}
```

**Observations**:
- 20+ claims
- 14+ service roles listed explicitly
- Nested permission structures
- Multiple organizational attributes
- Audience includes all possible services
- Token size: **2.5-3.5 KB** (often compressed to 1.5 KB at rest)

---

### Target State Token (New Model)

#### Header
```json
{
  "typ": "JWT",
  "alg": "RS256",
  "kid": "key-1"
}
```

#### Payload (Simplified)
```json
{
  "sub": "user123",
  "name": "Jane Smith",
  "email": "jane@company.com",
  "iss": "https://keycloak.company.com/auth/realms/app-realm",
  "aud": "microservices",
  "preferred_username": "jane.smith",
  "group": "internal",
  "business_role": "Manager",
  "exp": 1700000000,
  "iat": 1699996400,
  "jti": "abc123def456"
}
```

**Observations**:
- 9 claims (vs 20+)
- Single business role (vs 14+ service roles)
- Single audience (vs multiple services)
- No permission nesting
- No organizational attributes (kept in user profile service if needed)
- Token size: **400-600 bytes** (~20% of current size)

---

## What Spring Security Extracts

### From Current Token
```
Token arrives at service
  ↓
Spring Security extracts:
  - sub: "user123"
  - group: "GroupA"
  - roles: [array of 14 service-level roles]
  ↓
Service checks: Does user have "reports-admin" role?
  ↓
But ALSO: Does user have "user-editor" role? (not relevant here)
         Does user have "approval-approver" role? (not relevant here)
  ↓
Result: User has unwanted access to unrelated services
        (Permission inflation problem)
```

### From Target Token
```
Token arrives at service
  ↓
Spring Security extracts:
  - sub: "user123"
  - group: "internal"
  - business_role: "Manager"
  ↓
Service checks: Does user have "Manager" role?
  ↓
Result: Clear, simple permission decision
        (No role inflation)
```

---

## Token Size Comparison Table

| Metric | Current | Target | Reduction |
|--------|---------|--------|-----------|
| Payload Claims | 20+ | 9 | -55% |
| Role Claims | 14+ | 1 | -93% |
| Service Audience | 7 | 1 | -86% |
| Nested Structures | 3-4 | 0 | -100% |
| **Uncompressed Size** | 2.5-3.5 KB | 400-600 B | -85% |
| **Compressed Size** | ~1.5 KB | ~300 B | -80% |
| **TTL (typical)** | 5-15 min | 5-15 min | No change |
| **Signature Overhead** | 344 bytes | 344 bytes | No change |
| **Total Request Size** | 2-5 KB | 0.5-1 KB | -75% |

---

## Network & Performance Benefits

### Token Transmission (Per Request)

**Current State**:
```
User Request:
  GET /api/reports/team
  Authorization: Bearer eyJhbGc....[2.5-3.5 KB token]...=

Size: 2.5-3.5 KB per request
```

**Target State**:
```
User Request:
  GET /api/reports/team
  Authorization: Bearer eyJhbGc....[400-600 B token]...=

Size: 400-600 B per request
```

**Network Impact** (for 1000 requests/second):
- Current: 2.5-3.5 GB of token data
- Target: 400-600 MB of token data
- Savings: **6x reduction**

### Server Memory (Token Storage in Cache)

**Current State** (Cache 10,000 active tokens):
```
10,000 tokens × 3 KB = 30 MB in cache
Cache hit ratio: 80%
```

**Target State** (Cache 10,000 active tokens):
```
10,000 tokens × 0.5 KB = 5 MB in cache
Cache hit ratio: 80%
```

**Memory Savings**: 25 MB per cache instance

---

## Keycloak Configuration Changes

### Current Configuration (Old)

```yaml
# Keycloak Client Scopes
default-scopes:
  - profile
  - email
  - roles
  - permissions
  - department
  - cost_center

# Keycloak Protocol Mappers (14+)
mappers:
  - name: service-roles-mapper
    claim: roles
    full_path: false
  - name: reports-permission-mapper
    claim: permissions.services.reports-service
  - name: approval-permission-mapper
    claim: permissions.services.approval-service
  - name: realm-roles
    claim: realm_access.roles
  # ... 10+ more mappers ...
```

### Target Configuration (New)

```yaml
# Keycloak Client Scopes
default-scopes:
  - profile
  - email
  - business-role  # New

# Keycloak Protocol Mappers (Simplified)
mappers:
  - name: group-mapper
    claim: group
    group_attribute: name
  - name: business-role-mapper
    claim: business_role
    protocol: openid-connect
    mapper_type: user-realm-role-mapper
```

---

## Migration Impact Analysis

### Benefits

#### 1. Reduced Token Size
- 85% smaller tokens
- Faster transmission
- Lower network bandwidth
- Better for mobile/edge clients

#### 2. Simplified Permission Logic
- Single role to check (vs 14+ roles)
- Faster token validation
- Reduced Spring Security processing
- Cleaner audit logs

#### 3. Improved Security
- Reduced attack surface
- Fewer unintended permissions
- Clear role boundaries
- Better least-privilege enforcement

#### 4. Better Scalability
- 6x fewer bytes in flight
- Reduced cache memory requirements
- Lower CPU for token parsing
- Better load balancer efficiency

#### 5. Easier Debugging
- Cleaner token structure
- Fewer false role matches
- Better error context
- Simpler permission troubleshooting

### Challenges

#### 1. Configuration Changes Required
- Keycloak realm configuration
- Spring Security authorization rules
- Service-level permission checks
- Client scope modifications

#### 2. Migration Path Needed
- Phased token rollout
- Parallel old/new model support
- User migration planning
- Rollback capabilities

#### 3. Organizational Attributes
- Current: Department, Cost Center embedded in token
- Target: Fetch from user profile service
- Trade-off: One additional lookup per session
- Solution: Cache in application session

---

## Keycloak Token Extraction

### Current (Extracting from Bloated Token)

```java
// Spring Security Converter
public class JwtAuthenticationConverter implements Converter<Jwt, AbstractAuthenticationToken> {

    @Override
    public AbstractAuthenticationToken convert(Jwt jwt) {
        Collection<GrantedAuthority> authorities =
            jwt.getClaimAsList("roles", String.class)
               .stream()
               .map(role -> new SimpleGrantedAuthority("ROLE_" + role))
               .collect(Collectors.toList());

        // Extract 14+ roles (only need 1!)
        // This is inefficient and error-prone

        return new JwtAuthenticationToken(jwt, authorities);
    }
}
```

### Target (Extracting from Simplified Token)

```java
// Spring Security Converter
public class JwtAuthenticationConverter implements Converter<Jwt, AbstractAuthenticationToken> {

    @Override
    public AbstractAuthenticationToken convert(Jwt jwt) {
        String businessRole = jwt.getClaimAsString("business_role");
        String group = jwt.getClaimAsString("group");

        Collection<GrantedAuthority> authorities =
            Collections.singleton(new SimpleGrantedAuthority("ROLE_" + businessRole));

        // Extract single role - clear and simple
        // Custom claims for group context

        return new JwtAuthenticationToken(jwt, authorities);
    }
}
```

---

## Real-World Example: Token in HTTP Header

### Current State Request

```http
GET /api/reports/team-summary HTTP/1.1
Host: api.company.com
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImtleTEifQ.eyJzdWIiOiJ1c2VyMTIzIiwibmFtZSI6IkphbmUgU21pdGgiLCJlbWFpbCI6ImphbmVAY29tcGFueS5jb20iLCJpc3MiOiJodHRwczovL2tleWNsb2FrLmNvbXBhbnkuY29tL2F1dGgvcmVhbG1zL2FwcC1yZWFsbSIsImF1ZCI6WyJyZXBvcnRzLXNlcnZpY2UiLCJhcHByb3ZhbC1zZXJ2aWNlIiwidXNlci1zZXJ2aWNlIiwic2V0dGluZ3Mtc2VydmljZSIsImF1ZGl0LXNlcnZpY2UiLCJiYXRjaC1zZXJ2aWNlIiwiaW50ZWdyYXRpb24tc2VydmljZSJdLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJqYW5lLnNtaXRoIiwiZ2l2ZW5fbmFtZSI6IkphbmUiLCJmYW1pbHlfbmFtZSI6IlNtaXRoIiwiZ3JvdXAiOiJHcm91cEEiLCJyb2xlcyI6WyJyZXBvcnRzLXJlYWRlciIsInJlcG9ydHMtd3JpdGVyIiwicmVwb3J0cy1hZG1pbiIsImFwcHJvdmFsLXZpZXdlciIsImFwcHJvdmFsLWFwcHJvdmVyIiwiYXBwcm92YWwtYXVkaXRvciIsInVzZXItYWRtaW4iLCJ1c2VyLWVkaXRvciIsInVzZXItdmlld2VyIiwic2V0dGluZ3MtcmVhZGVyIiwic2V0dGluZ3MtZWRpdG9yIiwic2V0dGluZ3MtYWRtaW4iLCJhdWRpdC12aWV3ZXIiLCJhdWRpdC1leHBvcnRlciIsImF1ZGl0LWRlbGV0ZXIiLCJiYXRjaC1zY2hlZHVsZXIiLCJiYXRjaC1leGVjdXRvciIsImJhdGNoLWFkbWluIiwiaW50ZWdyYXRpb24tbWFuYWdlciIsImludGVncmF0aW9uLWV4ZWN1dG9yIl0sImNsaWVudF9pZCI6ImFwcC1jbGllbnQiLCJleHAiOjE3MDAwMDAwMDAsImlhdCI6MTY5OTk5NjQwMCwianRpIjoiYWJjMTIzZGVmNDU2In0.signature...
Content-Type: application/json
```

**Header Size**: ~2-3 KB (token only)

### Target State Request

```http
GET /api/reports/team-summary HTTP/1.1
Host: api.company.com
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImtleTEifQ.eyJzdWIiOiJ1c2VyMTIzIiwibmFtZSI6IkphbmUgU21pdGgiLCJlbWFpbCI6ImphbmVAY29tcGFueS5jb20iLCJpc3MiOiJodHRwczovL2tleWNsb2FrLmNvbXBhbnkuY29tL2F1dGgvcmVhbG1zL2FwcC1yZWFsbSIsImF1ZCI6Im1pY3Jvc2VydmljZXMiLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJqYW5lLnNtaXRoIiwiZ3JvdXAiOiJpbnRlcm5hbCIsImJ1c2luZXNzX3JvbGUiOiJNYW5hZ2VyIiwiZXhwIjoxNzAwMDAwMDAwLCJpYXQiOjE2OTk5OTY0MDAsImp0aSI6ImFiYzEyM2RlZjQ1NiJ9.signature...
Content-Type: application/json
```

**Header Size**: ~400-600 B (token only)

---

## Configuration Checklist for Migration

### Keycloak Changes

- [ ] Create new client scope: `business-role`
- [ ] Create protocol mapper for `group` claim
- [ ] Create protocol mapper for `business_role` claim
- [ ] Change audience from service list to `microservices`
- [ ] Remove service-specific role mappers
- [ ] Remove permission nested mappers
- [ ] Remove organizational attribute mappers
- [ ] Test token generation with new configuration
- [ ] Verify token size reduction

### Spring Security Changes

- [ ] Update `JwtAuthenticationConverter`
- [ ] Remove multi-role extraction logic
- [ ] Extract single `business_role` claim
- [ ] Extract `group` claim for context
- [ ] Update role prefix (e.g., `ROLE_Manager`)
- [ ] Update authorization annotations
- [ ] Test role extraction with new token

### Application Changes

- [ ] Update service permission configuration
- [ ] Migrate authorization rules from `@PreAuthorize("hasRole('...')")` patterns
- [ ] Create service-to-role mapping configuration
- [ ] Add fallback for organizational attributes (profile service)
- [ ] Update audit logging to new token structure

---

## Notes

- Token size reduction is **not** the primary goal—security improvement is
- Cleaner token = cleaner permission logic = fewer bugs
- Phase 1 focuses on service-level checks; Phase 2 will add fine-grained rules
- Signature and algorithm remain unchanged (still RS256)
- Token TTL and refresh behavior remain unchanged
