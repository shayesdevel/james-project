# Target Design: Simple Workflow Overview

## Summary

This document describes the simple, straightforward target state for authentication and authorization in the James project. The goal is to replace meaningless groups (Group A, Group B) with meaningful categories, migrate business roles into Keycloak, and provide direct service-level access based on business roles.

**Design Philosophy**: Keep it simple. Start with service-level access (Phase 1), then enhance with controller-level granularity later (Phase 2).

## Target State Architecture

### Three Meaningful Groups

Replace Group A and Group B with three clear, purposeful groups:

1. **External Users**
   - Customers, partners, vendors, external contractors
   - Limited access to customer-facing services
   - Restricted permissions

2. **Internal Users**
   - Employees, internal staff
   - Access to internal tools and services
   - Can be assigned User, Manager, or Admin business roles

3. **Services**
   - Service accounts, machine-to-machine communication
   - Inter-service authentication
   - Restricted to service-level operations

**Key Benefit**: Group names are self-explanatory and map to real business categories.

## Business Roles Migrated to Keycloak

### Current State (Broken)
- Business roles (User, Manager, Admin) exist in **application database**
- Spring Security checks via custom application logic
- No connection between Keycloak groups and business roles
- Authorization split between Keycloak and app DB

### Target State (Fixed)
- Business roles (User, Manager, Admin) exist in **Keycloak**
- Included in JWT tokens
- Spring Security checks roles from token
- Single source of truth for authorization

### Business Role Definitions

**User**
- Standard user with basic permissions
- Can access core services needed for day-to-day work
- Read/write access to their own resources
- Cannot perform administrative functions

**Manager**
- All User permissions
- Can manage team resources
- Access to reporting and analytics
- Can perform approval workflows
- Cannot perform system-wide administrative functions

**Admin**
- All Manager permissions
- System-wide administrative access
- Can manage users and configurations
- Access to all services

## Groups Assign Business Roles

**Core Pattern**: Groups determine which business roles can be assigned to users.

### External Users Group
- Can be assigned: **User role only**
- Rationale: External users should have limited, customer-facing permissions
- Cannot be Managers or Admins (internal-only functions)

### Internal Users Group
- Can be assigned: **User, Manager, OR Admin roles**
- Rationale: Internal employees can have varying levels of responsibility
- Actual role assigned based on job function

### Services Group
- Can be assigned: **Service role** (special role for service accounts)
- Rationale: Service accounts need service-to-service communication permissions
- Not assigned User/Manager/Admin roles

## Business Roles Grant Service-Level Access (Phase 1)

**Approach**: Business roles provide direct access to entire services.

**Pattern**:
```
User has Business Role (User, Manager, Admin)
  ↓
Business Role grants access to specific services
  ↓
Spring Security checks role in token
  ↓
Access granted or denied at service level
```

### Example Service Access Matrix (Phase 1)

| Business Role | User Service | Order Service | Payment Service | Admin Service | Reporting Service |
|---------------|--------------|---------------|-----------------|---------------|-------------------|
| User          | ✓            | ✓             | ✓               | ✗             | ✗                 |
| Manager       | ✓            | ✓             | ✓               | ✗             | ✓                 |
| Admin         | ✓            | ✓             | ✓               | ✓             | ✓                 |

**How It Works**:
- User role: Access to core services (user, order, payment)
- Manager role: User services + reporting/analytics
- Admin role: All services including administrative functions

**Simplicity**: Binary access at service level. If you have the role, you can call the service.

## User Creation Flow (Target State)

```
1. New user created in Keycloak
     ↓
2. Admin assigns user to group: External Users OR Internal Users
     ↓
3. Admin assigns business role: User, Manager, or Admin (based on group constraints)
     ↓
4. Business role grants service-level permissions
     ↓
5. User authenticates → JWT token includes group + business role
     ↓
6. Services check business role in token
     ↓
7. Access granted to services based on role
```

**Key Differences from Current State**:
- Groups are meaningful (External/Internal/Services)
- Business roles are in Keycloak (not app DB)
- Service access is determined by business role (not dozens of arbitrary service roles)
- Clear assignment logic (not automatic)

## Token Structure (Target State)

### JWT Token Claims
```json
{
  "sub": "user-123",
  "preferred_username": "alice@example.com",
  "email": "alice@example.com",
  "groups": ["Internal Users"],
  "realm_access": {
    "roles": ["Manager"]
  },
  "resource_access": {
    "user-service": {"roles": ["access"]},
    "order-service": {"roles": ["access"]},
    "payment-service": {"roles": ["access"]},
    "reporting-service": {"roles": ["access"]}
  }
}
```

**What's Included**:
- User identity claims
- Group membership (External Users, Internal Users, or Services)
- Business role (User, Manager, or Admin)
- Service access claims (based on business role)

**What's NOT Included**:
- Dozens of arbitrary service roles
- Group A or Group B
- Roles stored in application database

**Token Size**: Significantly smaller than current state (4-5 service access entries vs. dozens of service roles)

## Spring Security Integration (Phase 1)

### Service-Level Authorization

Each microservice checks for business role:

```java
@PreAuthorize("hasRole('MANAGER') or hasRole('ADMIN')")
@GetMapping("/api/reports")
public List<Report> getReports() {
    return reportService.findAll();
}
```

**Characteristics**:
- Simple role checks: User, Manager, or Admin
- Service determines if role is sufficient for access
- No custom database queries for roles
- Single source of truth (Keycloak token)

### Example: Order Service

```java
// Any authenticated user can view their orders
@PreAuthorize("hasRole('USER') or hasRole('MANAGER') or hasRole('ADMIN')")
@GetMapping("/api/orders/{id}")
public Order getOrder(@PathVariable Long id) {
    // Business logic handles ownership check
    return orderService.findById(id);
}

// Only managers and admins can view all orders
@PreAuthorize("hasRole('MANAGER') or hasRole('ADMIN')")
@GetMapping("/api/orders")
public List<Order> getAllOrders() {
    return orderService.findAll();
}
```

**Phase 1 Limitation**: Still checking at service level, not controller or resource level. Resource ownership must be handled in business logic.

## Phase 2 Enhancement (Future)

**Goal**: Add controller-level and resource-level granularity.

**What Phase 2 Will Add**:
- Fine-grained permissions at controller endpoint level
- Resource-level access control (user can only see their own orders)
- Action-level permissions (read vs. write vs. delete)
- Attribute-based access control (ABAC)

**Example Phase 2**:
```java
@PreAuthorize("hasPermission(#id, 'Order', 'READ')")
@GetMapping("/api/orders/{id}")
public Order getOrder(@PathVariable Long id) {
    return orderService.findById(id);
}
```

**Why Phase 2 is Later**:
- Phase 1 is simpler and faster to implement
- Service-level access solves the immediate over-permissioning problem
- Controller-level granularity can be added incrementally
- Don't over-design upfront

## Key Benefits of Target Design

### Simplicity
- Three meaningful groups vs. two meaningless groups
- Three business roles vs. dozens of service roles
- Clear naming: External/Internal/Services, User/Manager/Admin
- Easy to understand and explain

### Security
- Principle of least privilege: Users get only what they need
- Business roles map to actual job functions
- Service access based on role, not automatic assignment
- Single source of truth (Keycloak)

### Maintainability
- Business roles in Keycloak (not spread across app DBs)
- Fewer roles to manage (3 business roles vs. dozens of service roles)
- Clear group-to-role relationship
- Scales to new services easily

### Compliance
- Can demonstrate role-based access control
- Audit trail of role assignments
- Clear permission boundaries
- Separation of external and internal users

## Migration Path (High-Level)

1. **Create new groups in Keycloak**: External Users, Internal Users, Services
2. **Create business roles in Keycloak**: User, Manager, Admin
3. **Map business roles to service access**: Define which roles can access which services
4. **Migrate users from Group A/B to new groups**: Assign appropriate business roles
5. **Update Spring Security**: Check for business roles instead of service roles
6. **Remove old groups**: Delete Group A and Group B
7. **Clean up**: Remove business role tables from application databases

**Detailed steps**: See `../04-migration-plan/` directory

## Design Decisions

### Why Service-Level Access for Phase 1?

**Decision**: Business roles grant access to entire services, not individual endpoints.

**Rationale**:
- Simpler to implement and reason about
- Solves the immediate over-permissioning problem
- Reduces token size significantly
- Allows incremental enhancement (Phase 2)
- Provides clear upgrade path

**Trade-off**: Less granular than endpoint-level or resource-level control, but sufficient for initial implementation.

### Why Three Groups?

**Decision**: External Users, Internal Users, Services

**Rationale**:
- Covers all user categories
- Clear business meaning
- Enables different permission models for external vs. internal
- Service accounts separated from human users
- Simple enough to maintain

**Alternative Considered**: More granular groups (Customer, Partner, Employee, Contractor, Admin, Service)
**Why Not**: Adds complexity without proportional benefit. Business roles handle variation within groups.

### Why Business Roles in Keycloak?

**Decision**: Migrate User/Manager/Admin from app DB to Keycloak

**Rationale**:
- Single source of truth for authorization
- Roles included in JWT tokens
- No need for database queries on every request
- Consistent across all microservices
- Enables centralized role management

**Trade-off**: Requires migration effort, but pays long-term dividends.

## What This Fixes

### Current State Problems
- ✗ Meaningless groups (Group A, Group B)
- ✗ Dozens of service roles per user
- ✗ Business roles in app DB, not Keycloak
- ✗ No connection between groups and business roles
- ✗ Standard users have way too much permission
- ✗ Authorization split between Keycloak and app logic

### Target State Solutions
- ✓ Meaningful groups (External, Internal, Services)
- ✓ Three business roles (User, Manager, Admin)
- ✓ Business roles in Keycloak tokens
- ✓ Clear group-to-role mapping
- ✓ Service access based on business need
- ✓ Single source of truth in Keycloak

## Related Documentation

- [Group-Role Mapping](./group-role-mapping.md) - Detailed mapping between groups and roles
- [Current State Overview](../01-current-state/keycloak-overview.md) - What we're replacing
- [Migration Plan](../04-migration-plan/) - How to get from current to target

## Status

**Design Phase**: Initial - Phase 1 (Simple)
**Documented**: 2025-11-20
**Next Phase**: Phase 2 (Controller-level granularity) - future enhancement
**Implementation Status**: Not yet started
