# Keycloak Current State Overview

## Summary

Keycloak serves as the identity provider for the James project, managing authentication and initial authorization for 15+ Spring Boot microservices. This document describes how Keycloak is currently configured and how it grants roles to users.

## Architecture Context

**Identity Provider**: Keycloak
**Backend Services**: 15+ Spring Boot 3.5 microservices
**Frontend**: React UI
**API Gateway**: Kong
**Authorization Model**: Group-based role assignment (BROKEN - see [broken-authorization.md](./broken-authorization.md))

## Current Keycloak Configuration

### User Creation Flow

When a new user is created in Keycloak:
1. User account is provisioned
2. User is **automatically assigned to one or more groups**
3. Groups grant roles via predefined mappings
4. Roles appear in user's JWT tokens
5. Spring Security services check for roles in tokens

### Group Assignment Mechanism

**Current Groups**: New users are automatically assigned to **Group A** OR **Group B**

**Why These Groups Are Meaningless**:
- "Group A" and "Group B" have no business context
- Names provide no indication of purpose, responsibility, or access level
- Assignment logic between A vs. B is unclear
- No connection to actual job functions, departments, or roles

**What's Missing**:
- No business role representation (User, Manager, Admin exist in app DB, NOT in Keycloak)
- No meaningful categorization (External vs. Internal users, for example)
- No service account differentiation

### Role-to-Group Mapping

**Pattern**: Group A and Group B both inherit **dozens of service roles** with slight overlap.

**Structure**:
```
Group A
  ├─ service-a-role
  ├─ service-b-role
  ├─ service-c-role
  ├─ ... (dozens of service roles)
  └─ service-n-role

Group B
  ├─ service-a-role  (overlap with Group A)
  ├─ service-d-role
  ├─ service-e-role
  ├─ ... (dozens of service roles)
  └─ service-m-role
```

**The Problem**:
- Both groups grant **way too much permission** to services
- Standard users get access to services they shouldn't use
- Role proliferation: dozens of roles per user
- Slight overlap between groups creates confusion about what each group actually provides
- No clear differentiation in permission levels between Group A and Group B

**What These Are**:
- Service-level roles (one per microservice)
- Provide binary access: "Can access service X" or "Cannot access service X"
- No granularity within services (no read vs. write, no resource-level checks)

### Token Structure

When a user authenticates:
1. Keycloak issues JWT access token
2. Token includes **dozens of service roles** from Group A or Group B
3. Token contains:
   - User identity claims (sub, preferred_username, email)
   - Realm roles array with dozens of entries (one per service)
   - Resource access claims (if using client roles)
   - Group memberships (Group A or Group B)

**Consequence**: User tokens are bloated with dozens of service roles, most of which they should never use.

**What's NOT in Tokens**:
- Business roles (User, Manager, Admin) - these exist in the application database, NOT in Keycloak
- No mapping between Keycloak groups and business roles
- No indication of user's actual permissions or responsibilities

## Role Granting Process

### How Users Get Roles

```
User Created
    ↓
Auto-assigned to Groups
    ↓
Groups have predefined Role Mappings
    ↓
All Roles from all Groups added to User
    ↓
Roles appear in JWT tokens
    ↓
Spring Security checks token for roles
```

### Current State Facts

**What We Know**:
- Users get automatic group assignments at creation time
- Groups have no meaningful business context
- Each group grants multiple roles (one per microservice)
- Roles are checked by Spring Security in each service
- If role is present in token, access is granted (binary check)

**What This Means**:
- No granular permission model
- No resource-level authorization
- No action-level authorization (read vs. write)
- No context-aware authorization
- Every authenticated user has access to most/all services

## Integration with Spring Boot Services

### Service-Side Authorization

Each Spring Boot microservice:
1. Receives JWT token from API Gateway (Kong)
2. Validates token signature (trust relationship with Keycloak)
3. Extracts roles from token claims
4. Uses Spring Security `@PreAuthorize` or similar annotations
5. Checks: "Does token contain role X?"
6. If yes: grant access
7. If no: deny access

**Example Pattern** (assumed):
```java
@PreAuthorize("hasRole('service-a-role')")
@GetMapping("/api/sensitive-data")
public ResponseEntity<?> getSensitiveData() {
    // Access granted if role present
}
```

### Why This Is Problematic

Since ALL users get ALL roles through automatic group assignment:
- Binary role check (`hasRole`) always returns `true`
- Authorization effectively becomes authentication
- "Are you logged in?" becomes the only real check
- No differentiation between user types or permissions

See [broken-authorization.md](./broken-authorization.md) for detailed security implications.

## Configuration Assumptions

Based on the described behavior, Keycloak is likely configured with:

**Realm Settings**:
- Default groups enabled (users auto-join groups)
- Group-to-role mappings configured at realm or group level
- Roles created for each microservice

**Client Settings** (for Spring Boot services):
- Client protocol: openid-connect
- Access type: confidential or bearer-only
- Role scope mappings enabled
- Full scope allowed (all realm roles included in tokens)

**User Federation**:
- Unknown if external user store (LDAP, AD) is involved
- Group assignment may be affected by federation mappers

**Investigation Needed**:
- [ ] Realm configuration export
- [ ] Client configuration details
- [ ] Federation settings (if any)
- [ ] Default group settings
- [ ] Role scope mappings

## Kong API Gateway Role

**Assumed Flow**:
```
React UI → Kong Gateway → Keycloak (authenticate) → JWT Token → Kong → Spring Boot Service
```

**Kong's Likely Responsibilities**:
- Route requests to appropriate microservices
- Handle OIDC authentication flow with Keycloak
- Attach validated JWT to upstream requests
- May perform initial token validation

**Investigation Needed**:
- [ ] Kong OIDC plugin configuration
- [ ] Does Kong perform any authorization checks?
- [ ] How are tokens passed to upstream services?
- [ ] Token validation vs. token introspection

## Known Limitations

Based on current configuration:

1. **No Role Hierarchy**: Flat role structure with no inheritance
2. **No Dynamic Roles**: Roles assigned at user creation, not at runtime
3. **No Resource-Based Roles**: Roles are service-level, not resource-level
4. **No Attribute-Based Access**: No ABAC, only RBAC (broken RBAC at that)
5. **No Permission Policies**: Binary yes/no based on role presence

## Questions Requiring Investigation

### Critical Questions
- What are the actual group names and how many exist?
- What is the exact role naming convention?
- How many roles does an average user receive?
- Is there ANY variation in role assignments between users?

### Configuration Questions
- Is group assignment triggered by realm defaults or registration flow?
- Are roles realm-level or client-level?
- What token claims contain role information?
- Does Kong perform any authorization logic?

### Business Logic Questions
- What was the original intent of these groups?
- Are there supposed to be different user types or tiers?
- What should the permission boundaries actually be?
- Which services should NOT be universally accessible?

## Next Steps

To complete this documentation:
1. Export realm configuration from Keycloak
2. Capture sample token structure (anonymized)
3. Document actual group names and role names
4. Verify Kong configuration
5. Interview stakeholders about intended access patterns

## Related Documentation

- [Broken Authorization](./broken-authorization.md) - Security implications
- [Group-Based Issues](./group-based-issues.md) - Technical breakdown of failures
- [README](../README.md) - Documentation navigation

## Status

**Documented**: 2025-11-20
**Completeness**: Partial - based on problem description, requires verification
**Next Phase**: Technical investigation to fill knowledge gaps
