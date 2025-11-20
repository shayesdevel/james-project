# Group-Based Authorization: Technical Breakdown

## Overview

This document provides a detailed technical analysis of why the group-based authorization model fails at scale, how Spring Security integration compounds the problem, and the specific architectural patterns that create the security catastrophe.

**Focus**: Technical implementation details and why this approach doesn't scale.

## The Group-Based Pattern

### Conceptual Model

```
Groups ──(grant)──> Roles ──(check)──> Access
```

**In Theory**:
- Groups represent collections of users with similar needs
- Roles represent permissions or capabilities
- Services check roles to grant access

**In Practice** (current implementation):
- Groups are meaningless organizational artifacts
- Roles are per-service identifiers with no granularity
- Services perform binary existence checks only

## Why Groups Don't Work at Scale

### Problem 1: Wrong Abstraction Level

**Groups Should Represent**: Collections of users organized by business concept
- Job functions (Managers, Analysts, Support Staff)
- Organizational units (Sales, Engineering, Finance)
- Responsibility levels (Approvers, Reviewers, Viewers)

**Groups Actually Represent** (current system): Nothing meaningful
- Auto-assigned buckets
- No mapping to business concepts
- No relationship to actual user responsibilities

**Why This Fails**:
```
Business Concept → Group → Roles → Access
     ❌              ❌      ✓       ✓

If groups don't represent business concepts,
the entire chain is broken at the foundation.
```

### Problem 2: Group-to-Role Mapping Explosion

**Pattern**: Each group grants one role per microservice

**Math** (with 15 microservices):
- 1 group → 15 roles (one per service)
- 3 groups → 45 roles total
- If user is in 3 groups → user has 45 roles in token

**Scalability Issues**:
1. **Token Bloat**: JWT tokens grow with every service added
2. **Mapping Maintenance**: Adding a new service requires updating all group mappings
3. **No Clear Ownership**: Who decides which group gets which role for new service?
4. **Configuration Drift**: Groups accumulate roles without clear governance

### Problem 3: No Semantic Meaning

**Group Names** (hypothetical examples):
- "default-users"
- "authenticated-group"
- "basic-access"

**What These Don't Tell You**:
- What does this group represent?
- Who should be in this group?
- What permissions should this group have?
- Why does this group grant access to service X?

**Impact**:
- Cannot make informed authorization decisions
- Cannot audit access appropriately
- Cannot explain to compliance why group X has access to service Y
- Cannot design group membership criteria

### Problem 4: Static Assignment at Creation Time

**Current Behavior**: Groups assigned when user is created

**Why This Is Wrong**:
1. **User Roles Change**: Promotions, transfers, responsibility changes
2. **Service Access Changes**: New projects, temporary assignments, contractor access
3. **No Lifecycle Management**: How do users lose access when they change roles?
4. **No Temporal Access**: Cannot grant time-limited access

**Example Scenario**:
```
Day 1: User joins as Customer Support → Gets "default-users" group → 15 roles
Day 30: User promoted to Manager → Still has same groups → Still 15 roles
Day 60: User moves to Engineering → Still has same groups → Still 15 roles
Day 90: User leaves company → Account disabled, but group model taught us nothing about actual access needs
```

**Learning**: The group model provides no insight into actual access patterns or needs.

## Spring Security Integration Failures

### Binary Role Check Pattern

**Typical Implementation**:
```java
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @PreAuthorize("hasRole('order-service-role')")
    @GetMapping("/{id}")
    public Order getOrder(@PathVariable Long id) {
        return orderService.findById(id);
    }

    @PreAuthorize("hasRole('order-service-role')")
    @PostMapping
    public Order createOrder(@RequestBody Order order) {
        return orderService.create(order);
    }

    @PreAuthorize("hasRole('order-service-role')")
    @DeleteMapping("/{id}")
    public void deleteOrder(@PathVariable Long id) {
        orderService.delete(id);
    }
}
```

**What This Checks**:
- Does token contain the role 'order-service-role'?
- If YES → Allow
- If NO → Deny (HTTP 403)

**What This DOESN'T Check**:
- Who is the user?
- What is their relationship to this resource?
- What action are they trying to perform?
- Is this action appropriate for their job function?
- Are there business rules that should apply?

### Why Binary Checks Fail

**Scenario**: Order Management Service

**Business Requirements**:
1. Customers can view their own orders only
2. Customer support can view any order but not modify
3. Order managers can view and modify any order
4. Finance can view orders but only for reporting
5. External partners cannot access order service at all

**Current Implementation**:
```java
@PreAuthorize("hasRole('order-service-role')")
```

**Who Gets Access?**:
- All authenticated users (they all have 'order-service-role')

**Violations**:
1. ❌ Customers can view other customers' orders
2. ❌ Customer support can modify orders (should be read-only)
3. ❌ No distinction between view and modify permissions
4. ❌ Finance can see all data (even if they only need aggregates)
5. ❌ External partners get access (shouldn't have any)

### The Service-Level Role Pattern

**Current Pattern**: One role per service
- order-service-role
- payment-service-role
- inventory-service-role
- shipping-service-role
- etc.

**What This Means**:
- Binary access: you have access to the entire service or you don't
- No granularity within the service
- No distinction between operations (read vs. write vs. delete)
- No resource-level permissions

**Why This Doesn't Scale**:

**Example**: Payment Service
```
Business Need: Different access levels
- Customers: Can view their own payment history
- Support: Can view payment details (read-only)
- Finance: Can view and refund payments
- External Auditors: Can view historical payments (read-only)

Current Implementation:
@PreAuthorize("hasRole('payment-service-role')")

Result: ALL or NOTHING
```

Cannot express:
- View vs. modify permissions
- Own resources vs. all resources
- Read-only vs. full access
- Time-limited access
- Context-dependent access

### Spring Security Capabilities Not Being Used

**What Spring Security CAN Do** (but isn't being used):
1. **Expression-Based Access Control**:
   ```java
   @PreAuthorize("hasRole('ADMIN') or (hasRole('USER') and #order.userId == principal.id)")
   ```

2. **Method-Level Security**:
   ```java
   @PostAuthorize("returnObject.userId == principal.id")
   ```

3. **Custom Permission Evaluators**:
   ```java
   @PreAuthorize("hasPermission(#order, 'WRITE')")
   ```

4. **Hierarchical Roles**:
   ```
   ROLE_ADMIN > ROLE_MANAGER > ROLE_USER
   ```

**Why These Aren't Used**:
- Keycloak provides flat role list in token
- No permission metadata beyond role names
- No resource ownership information in tokens
- No hierarchical role relationships configured

## Microservice Scale Problems

### Problem Multiplication Across 15+ Services

**With 15 Services**:
- 15 separate codebases implementing authorization
- 15 separate role checks
- 15 opportunities for implementation inconsistency
- 15 different interpretations of the same role

**Example Inconsistency**:
```java
// Service A: Strict interpretation
@PreAuthorize("hasRole('admin-service-role')")
public void criticalOperation() { ... }

// Service B: Loose interpretation
@PreAuthorize("hasRole('admin-service-role') or hasRole('user-service-role')")
public void criticalOperation() { ... }

// Service C: No check at all (assumes API gateway handles it)
public void criticalOperation() { ... }
```

**Impact**:
- Inconsistent security posture
- Difficult to audit (must review all services)
- No centralized policy enforcement
- Each service interprets roles differently

### Service Interdependency Issues

**Scenario**: Service A calls Service B

**Current Pattern**:
```
User Request → Service A → Service B
         [JWT token passed through]
```

**Authorization Flow**:
1. User token has 'service-a-role' → Service A allows request
2. Service A calls Service B with same user token
3. User token has 'service-b-role' → Service B allows request
4. Response bubbles back to user

**Problems**:
1. **No Delegation Control**: Service B can't distinguish between:
   - User directly calling Service B
   - Service A calling Service B on behalf of user
   - Service A calling Service B for its own purposes

2. **Privilege Escalation Risk**:
   ```
   User shouldn't access Service B directly
   But Service A needs to call Service B
   User's token grants access to Service B
   → User can bypass Service A and call Service B directly
   ```

3. **No Call Chain Validation**:
   - Cannot enforce "Service B can only be called by Service A"
   - Cannot implement approval workflows
   - Cannot audit which service actually initiated request

### Configuration Drift Across Services

**Problem**: 15 services, each with their own understanding of authorization

**Drift Examples**:

**Service 1**: Uses role prefix 'ROLE_'
```java
@PreAuthorize("hasRole('ROLE_user-service-role')")
```

**Service 2**: No role prefix
```java
@PreAuthorize("hasRole('user-service-role')")
```

**Service 3**: Uses authority instead of role
```java
@PreAuthorize("hasAuthority('user-service-role')")
```

**Service 4**: Custom security configuration
```java
// Strips 'ROLE_' prefix from token
```

**Impact**:
- Same role name behaves differently across services
- Token structure must accommodate all variations
- Debugging authorization failures is difficult
- No consistent authorization model

## Token Structure Problems

### Token Bloat

**Typical JWT Token Structure** (current system):
```json
{
  "sub": "user123",
  "email": "user@example.com",
  "realm_access": {
    "roles": [
      "user-service-role",
      "order-service-role",
      "payment-service-role",
      "inventory-service-role",
      "shipping-service-role",
      "analytics-service-role",
      "reporting-service-role",
      "admin-service-role",
      "billing-service-role",
      "customer-service-role",
      "notification-service-role",
      "audit-service-role",
      "integration-service-role",
      "export-service-role",
      "import-service-role"
    ]
  }
}
```

**Problems**:
1. **Size**: 15+ roles × average 20 characters = 300+ bytes just for roles
2. **Network Overhead**: Large token in every HTTP request
3. **Storage**: Browser storage limits, cookie size limits
4. **Scalability**: Adding services grows token size
5. **Information Disclosure**: Token reveals all services in architecture

### No Contextual Information

**What's Missing from Tokens**:
- User's actual job function or title
- User's department or organizational unit
- User's permission scope (what resources they can access)
- User's access level (read-only, full access, admin)
- Resource ownership information
- Temporal access grants (time-limited permissions)

**Why This Matters**:
Services cannot make intelligent authorization decisions without context.

**Example**:
```java
// Cannot implement this logic with current token:
if (user.department == "Finance" && resource.type == "FinancialReport") {
    allow();
} else if (user.id == resource.ownerId) {
    allow();
} else if (user.hasTemporaryAccess(resource.id, currentTime)) {
    allow();
} else {
    deny();
}
```

## Why This Doesn't Scale: A Case Study

### Scenario: Adding the 16th Microservice

**New Service**: Customer Portal Service

**Requirements**:
- Customers can view their own data only
- Support staff can view any customer data (read-only)
- Account managers can view and modify customer data
- External partners should have no access

**Current Approach** (group-based):

**Step 1**: Create role in Keycloak
- Create `customer-portal-role`

**Step 2**: Add role to existing groups
- Add `customer-portal-role` to "default-users" group
- Add `customer-portal-role` to "authenticated-group" group
- Add `customer-portal-role` to any other auto-assigned groups

**Step 3**: Implement in service
```java
@PreAuthorize("hasRole('customer-portal-role')")
```

**Result**:
- ✓ Service is protected (requires authentication)
- ❌ All authenticated users have access
- ❌ No distinction between customers, support, managers, partners
- ❌ Cannot enforce "view own data only"
- ❌ Cannot enforce read-only for support staff
- ❌ External partners get access (security violation)

**Conclusion**: Adding a service with real security requirements is impossible with current model.

### Alternative: What Should Happen

**Step 1**: Define permissions (not roles)
- `customer-portal:read:own` - Read own customer data
- `customer-portal:read:all` - Read any customer data
- `customer-portal:write:all` - Modify any customer data

**Step 2**: Map permissions to job functions
- Customers → `customer-portal:read:own`
- Support → `customer-portal:read:all`
- Account Managers → `customer-portal:read:all`, `customer-portal:write:all`
- External Partners → (no permissions)

**Step 3**: Implement fine-grained checks
```java
@PreAuthorize("hasPermission(#customerId, 'Customer', 'read')")
public Customer getCustomer(@PathVariable Long customerId) {
    // Permission evaluator checks:
    // - Does user have 'customer-portal:read:all'? → Allow
    // - Does user have 'customer-portal:read:own' AND customerId == user.id? → Allow
    // - Otherwise → Deny
}
```

**Result**:
- ✓ Customers can only see their own data
- ✓ Support has read-only access to all customers
- ✓ Managers can modify customer data
- ✓ External partners are denied
- ✓ Scales to new services with different requirements

## Anti-Patterns Identified

### Anti-Pattern 1: Authentication as Authorization

**Pattern**: Using authentication to imply authorization
```java
if (user.isAuthenticated()) {
    // Grant access
}
```

**Why It's Wrong**:
- Being authenticated doesn't mean you should have access to everything
- No distinction between different user types
- No resource-level or action-level control

### Anti-Pattern 2: Service-Level Granularity Only

**Pattern**: One role per service, no finer granularity
```java
@PreAuthorize("hasRole('service-role')")
```

**Why It's Wrong**:
- Services have multiple resources and operations
- Different users need different access within same service
- Cannot express read vs. write vs. delete
- Cannot express "own resources only"

### Anti-Pattern 3: Automatic Universal Access

**Pattern**: Auto-assigning groups that grant wide access
```
User Created → Auto-Assign Groups → Auto-Grant Roles → Universal Access
```

**Why It's Wrong**:
- Violates least privilege principle
- No consideration of actual user needs
- Scales in wrong direction (more users = more over-permissioning)
- Cannot revoke access without disrupting legitimate users

### Anti-Pattern 4: Stateless Tokens with Broad Permissions

**Pattern**: JWT tokens containing all possible roles
```json
{
  "roles": ["service1", "service2", ..., "service15"]
}
```

**Why It's Wrong**:
- Cannot revoke specific permissions without token invalidation
- Token reveals system architecture
- Large tokens affect performance
- No way to update permissions during token lifetime

## Correct Patterns (Not Currently Implemented)

### Pattern 1: Permission-Based Authorization

**Instead of**: Role = Service
**Use**: Permission = Action + Resource Type + Scope

**Example**:
```
Permission: "orders:read:own"
  ↳ Action: read
  ↳ Resource: orders
  ↳ Scope: own (only resources I own)

Permission: "orders:write:all"
  ↳ Action: write
  ↳ Resource: orders
  ↳ Scope: all (any order)
```

### Pattern 2: Resource-Based Authorization

**Instead of**: Service-level checks
**Use**: Resource ownership and relationship checks

**Example**:
```java
@PreAuthorize("hasPermission(#orderId, 'Order', 'read')")
public Order getOrder(@PathVariable Long orderId) {
    // Permission evaluator checks resource ownership
}
```

### Pattern 3: Attribute-Based Access Control (ABAC)

**Instead of**: Binary role checks
**Use**: Policy-based decisions considering multiple attributes

**Example Policy**:
```
ALLOW if:
  - user.department = "Finance" AND
  - resource.type = "FinancialReport" AND
  - resource.department = user.department AND
  - action = "read"
```

### Pattern 4: Hierarchical Roles with Permission Mapping

**Instead of**: Flat role list
**Use**: Role hierarchy with permission composition

**Example**:
```
Role: CUSTOMER
  ├─ Permissions: ["customer-portal:read:own", "orders:read:own"]

Role: SUPPORT (inherits CUSTOMER)
  ├─ Permissions: ["customer-portal:read:all", "orders:read:all"]

Role: MANAGER (inherits SUPPORT)
  ├─ Permissions: ["customer-portal:write:all", "orders:write:all"]
```

## Migration Challenges

### Why This Can't Be Fixed with Minor Changes

**Attempting to Fix Current Model**:
1. Add more groups → Group explosion, still wrong abstraction
2. Add more roles → Token bloat, still service-level granularity
3. Add manual checks in code → Bypasses Keycloak, inconsistent across services
4. Remove auto-assignment → Manual overhead, still group-based model

**Fundamental Issues**:
- Wrong abstraction (groups don't map to business concepts)
- Wrong granularity (service-level instead of resource-level)
- Wrong enforcement point (binary role check instead of policy evaluation)
- Wrong token structure (flat role list instead of permissions or claims)

### What Needs to Change

**Architecture Level**:
1. Move from group-based to permission-based model
2. Implement resource-level authorization
3. Add policy decision point (PDP) for complex rules
4. Restructure tokens to contain permissions or claims, not all roles

**Service Level**:
1. Replace `hasRole()` checks with `hasPermission()` checks
2. Implement custom permission evaluators
3. Add resource ownership tracking
4. Implement consistent authorization patterns across all services

**Keycloak Level**:
1. Define permission model (actions, resources, scopes)
2. Map job functions to permissions (not services to roles)
3. Remove auto-assigned groups (or make them meaningful)
4. Configure proper token claims

## Summary

### Key Findings

**Group-Based Model Fails Because**:
1. Groups don't represent meaningful business concepts
2. Group-to-role mapping creates role explosion
3. Auto-assignment violates least privilege
4. No lifecycle management for changing user needs

**Spring Security Integration Fails Because**:
1. Binary role checks have no granularity
2. Service-level roles don't support resource-level authorization
3. Capabilities like permission evaluators aren't being used
4. Inconsistent implementation across microservices

**Scalability Fails Because**:
1. Adding services requires updating all group mappings
2. Token size grows with every service
3. No way to express fine-grained permissions
4. Each service interprets roles independently

### Root Cause

**The fundamental problem**: Authorization model was designed for service-level access control, but business requirements demand resource-level and action-level access control.

**The consequence**: Catastrophic over-permissioning that violates security principles and compliance requirements.

### Path Forward

See future documentation in `02-target-design/` for:
- Permission-based authorization model
- Resource-level access control patterns
- Policy-based decision framework
- Token structure redesign
- Migration strategy

## Related Documentation

- [Keycloak Overview](./keycloak-overview.md) - Current configuration
- [Broken Authorization](./broken-authorization.md) - Security implications
- [README](../README.md) - Documentation navigation

## Status

**Documented**: 2025-11-20
**Technical Assessment**: Current model cannot support business requirements
**Recommendation**: Complete redesign required
**Priority**: CRITICAL
