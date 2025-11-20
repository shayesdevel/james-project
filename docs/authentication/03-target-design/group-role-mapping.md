# Target Design: Group-Role Mapping

## Summary

This document defines the relationship between Keycloak groups and business roles in the target design. It explains which groups can assign which roles, provides concrete examples, and documents the "groups assign roles" pattern.

**Core Principle**: Groups represent user categories (External, Internal, Services). Business roles (User, Manager, Admin) are assigned within groups based on job function.

## Groups-Assign-Roles Pattern

### How It Works

```
1. User is assigned to a GROUP
     ↓
2. Group determines WHICH ROLES are available
     ↓
3. Admin assigns specific BUSINESS ROLE to user (within group constraints)
     ↓
4. Business Role appears in JWT token
     ↓
5. Services check Business Role for authorization
```

**Key Insight**: Groups are containers that constrain which roles can be assigned. The actual role assignment happens within the group's allowed roles.

## Group Definitions and Role Constraints

### External Users Group

**Purpose**: Customers, partners, vendors, external contractors, third-party integrators

**Allowed Business Roles**:
- **User** (standard external user role)

**Forbidden Business Roles**:
- Manager (internal-only function)
- Admin (internal-only function)

**Rationale**:
- External users should only have customer-facing permissions
- Managers and Admins are internal job functions
- Prevents external users from accessing internal tools or administrative functions

**Example Use Cases**:
- Customer accessing their account and orders
- Partner viewing integration status
- Vendor submitting invoices
- Contractor accessing limited project resources

### Internal Users Group

**Purpose**: Employees, internal staff, internal contractors with company credentials

**Allowed Business Roles**:
- **User** (standard employee)
- **Manager** (team lead, manager, supervisor)
- **Admin** (system administrator, IT staff)

**Rationale**:
- Internal users can have varying levels of responsibility
- Job function determines which role is assigned
- Supports organizational hierarchy

**Example Use Cases**:
- User: Sales rep, customer support, data entry staff
- Manager: Department manager, team lead, project manager
- Admin: IT administrator, system engineer, security staff

### Services Group

**Purpose**: Service accounts, machine-to-machine authentication, background jobs

**Allowed Business Roles**:
- **Service** (special role for service accounts)

**Forbidden Business Roles**:
- User, Manager, Admin (human user roles)

**Rationale**:
- Service accounts have different permission requirements
- Not tied to human job functions
- Enables service-to-service communication

**Example Use Cases**:
- Microservice calling another microservice
- Background job accessing databases
- Scheduled task running reports
- Integration service pulling data from external APIs

## Detailed Group-Role Matrix

| Group           | User Role | Manager Role | Admin Role | Service Role |
|-----------------|-----------|--------------|------------|--------------|
| External Users  | ✓         | ✗            | ✗          | ✗            |
| Internal Users  | ✓         | ✓            | ✓          | ✗            |
| Services        | ✗         | ✗            | ✗          | ✓            |

**Legend**:
- ✓ = Role can be assigned to users in this group
- ✗ = Role cannot be assigned to users in this group

## Role Assignment Examples

### Example 1: New Customer Sign-Up

**Scenario**: Customer creates account through website

```
1. User registers on website
2. Keycloak account created
3. Admin (or automated process) assigns user to: External Users group
4. User is assigned role: User
5. Token includes:
   - Group: External Users
   - Role: User
6. User can access customer-facing services only
```

**Permissions**:
- Can view their own account
- Can place and view their own orders
- Can access customer support
- Cannot access internal tools
- Cannot access administrative functions

### Example 2: New Employee Onboarding

**Scenario**: Sales representative joins company

```
1. HR creates Keycloak account
2. User assigned to: Internal Users group
3. User assigned role: User (standard employee)
4. Token includes:
   - Group: Internal Users
   - Role: User
5. User can access internal services for their job function
```

**Permissions**:
- Can access CRM and sales tools
- Can view customer data (within service's business logic constraints)
- Can create orders on behalf of customers
- Cannot access reporting/analytics (Manager only)
- Cannot access admin tools (Admin only)

### Example 3: Promotion to Manager

**Scenario**: Sales rep promoted to sales manager

```
1. Admin updates user's role in Keycloak
2. User remains in: Internal Users group
3. Role changed from: User → Manager
4. Token includes:
   - Group: Internal Users
   - Role: Manager
5. User gains additional permissions
```

**New Permissions**:
- All User permissions
- Can access reporting and analytics
- Can view team performance data
- Can approve orders above certain thresholds
- Still cannot access system administration tools

### Example 4: IT Administrator

**Scenario**: IT staff member with full system access

```
1. IT creates Keycloak account
2. User assigned to: Internal Users group
3. User assigned role: Admin
4. Token includes:
   - Group: Internal Users
   - Role: Admin
5. User has full system access
```

**Permissions**:
- All Manager permissions
- Access to administrative services
- Can manage users and configurations
- Can access all services
- Can perform system-level operations

### Example 5: Service Account for Background Jobs

**Scenario**: Nightly reporting job needs to access multiple services

```
1. Admin creates service account in Keycloak
2. Account assigned to: Services group
3. Account assigned role: Service
4. Token includes:
   - Group: Services
   - Role: Service
5. Service account can perform inter-service operations
```

**Permissions**:
- Can call other microservices
- Can access data for reporting
- Not tied to specific user context
- Different permission model than human users

## Business Role Definitions

### User Role

**Purpose**: Standard user with basic permissions

**Typical Job Functions**:
- Customer support representatives
- Sales representatives
- Data entry staff
- Standard employees

**Service Access** (Phase 1):
- User service (account management)
- Order service (create/view orders)
- Payment service (process payments)
- Customer service (support tickets)

**Cannot Access**:
- Reporting service
- Admin service
- Audit service

**Example Spring Security Check**:
```java
@PreAuthorize("hasRole('USER')")
@GetMapping("/api/orders")
public List<Order> getMyOrders() {
    // User can only see their own orders (enforced by business logic)
    return orderService.findByCurrentUser();
}
```

### Manager Role

**Purpose**: All User permissions + management and reporting capabilities

**Typical Job Functions**:
- Department managers
- Team leads
- Project managers
- Supervisors

**Service Access** (Phase 1):
- All User services
- Reporting service (analytics, dashboards)
- Analytics service (business intelligence)

**Cannot Access**:
- Admin service (system administration)

**Example Spring Security Check**:
```java
@PreAuthorize("hasRole('MANAGER') or hasRole('ADMIN')")
@GetMapping("/api/reports/team-performance")
public Report getTeamPerformance() {
    return reportService.generateTeamReport();
}
```

### Admin Role

**Purpose**: All Manager permissions + system-wide administrative access

**Typical Job Functions**:
- System administrators
- IT staff
- Security engineers
- Senior leadership (with technical access needs)

**Service Access** (Phase 1):
- All services (no restrictions)

**Example Spring Security Check**:
```java
@PreAuthorize("hasRole('ADMIN')")
@PostMapping("/api/admin/users/{id}/disable")
public void disableUser(@PathVariable Long id) {
    userService.disableUser(id);
}
```

### Service Role

**Purpose**: Service-to-service communication and background operations

**Typical Use Cases**:
- Background job service accounts
- Integration service accounts
- Scheduled task runners
- Inter-service authentication

**Service Access** (Phase 1):
- Services needed for specific job function
- Configured per service account
- Not all-or-nothing like Admin

**Example Spring Security Check**:
```java
@PreAuthorize("hasRole('SERVICE') or hasRole('ADMIN')")
@PostMapping("/api/internal/batch-process")
public void batchProcess(@RequestBody BatchRequest request) {
    batchService.process(request);
}
```

## Group Assignment Logic

### Who Assigns Groups?

**Manual Assignment**:
- Admin assigns groups during user creation
- Based on user type: External vs. Internal vs. Service

**Automated Assignment** (Optional Future Enhancement):
- External Users: Self-registration flow auto-assigns External Users group
- Internal Users: LDAP/AD integration auto-assigns based on company directory
- Services: API or automation tool creates service accounts with Services group

### Who Assigns Roles Within Groups?

**Initial Assignment**:
- Admin assigns role during user creation
- Based on job function or responsibility level

**Role Changes**:
- Admin updates role when user changes positions (promotion, transfer, etc.)
- Audit trail maintained in Keycloak

**Self-Service** (Optional Future Enhancement):
- Managers can request role changes for their team members
- Workflow approval process
- Admin final approval

## Service Access Matrix (Phase 1)

Mapping from business roles to service-level access:

| Service              | User | Manager | Admin | Service |
|----------------------|------|---------|-------|---------|
| user-service         | ✓    | ✓       | ✓     | ✓       |
| order-service        | ✓    | ✓       | ✓     | ✓       |
| payment-service      | ✓    | ✓       | ✓     | ✓       |
| customer-service     | ✓    | ✓       | ✓     | ✓       |
| notification-service | ✓    | ✓       | ✓     | ✓       |
| reporting-service    | ✗    | ✓       | ✓     | ✓       |
| analytics-service    | ✗    | ✓       | ✓     | ✓       |
| admin-service        | ✗    | ✗       | ✓     | ✗       |
| audit-service        | ✗    | ✗       | ✓     | ✓       |
| integration-service  | ✗    | ✗       | ✓     | ✓       |

**Legend**:
- ✓ = Role grants access to this service
- ✗ = Role does not grant access to this service

**Note**: This is an example matrix. Actual services and mappings should be defined based on James project's specific services and business requirements.

## Keycloak Configuration

### Group Configuration

**External Users Group**:
```
Name: External Users
Description: Customers, partners, and external users
Default Role: User
Role Constraints: User only
```

**Internal Users Group**:
```
Name: Internal Users
Description: Employees and internal staff
Default Role: User
Role Constraints: User, Manager, or Admin
```

**Services Group**:
```
Name: Services
Description: Service accounts and machine-to-machine
Default Role: Service
Role Constraints: Service only
```

### Role Mappers

**Realm Roles**:
- User
- Manager
- Admin
- Service

**Role Scope**: All roles are realm-level roles (not client-level)

**Token Mapping**:
- Roles included in `realm_access.roles` claim
- Groups included in `groups` claim
- Services can check either roles or groups

## Migration from Current State

### Current State
```
User → Group A or Group B → Dozens of service roles
Business roles (User, Manager, Admin) in app database
```

### Target State
```
User → External/Internal/Services group → Business role (User/Manager/Admin) → Service access
Business roles in Keycloak tokens
```

### Migration Steps (High-Level)

1. **Create new groups**: External Users, Internal Users, Services
2. **Create business roles**: User, Manager, Admin, Service
3. **Map roles to service access**: Configure role-to-service mappings
4. **Migrate users**:
   - Determine if user is External or Internal
   - Look up business role in app database
   - Assign to appropriate group and role in Keycloak
5. **Update Spring Security**: Check for business roles instead of service roles
6. **Remove old groups**: Delete Group A and Group B
7. **Clean up app database**: Remove business role tables

**Detailed migration plan**: See `../04-migration-plan/` directory

## Advantages of This Design

### Clear Naming
- Group names are self-explanatory: External Users, Internal Users, Services
- Role names match job functions: User, Manager, Admin
- No ambiguity about what each group or role represents

### Scalability
- New services can be added without creating new groups or roles
- Service access matrix can be updated without changing group structure
- Roles can be refined over time (Phase 2 enhancements)

### Maintainability
- Three groups vs. dozens of meaningless groups
- Three business roles vs. dozens of service roles
- Clear constraints on which roles can be assigned to which groups
- Single source of truth (Keycloak)

### Security
- Principle of least privilege: Users get only what they need
- External users separated from internal users
- Service accounts separated from human users
- Clear audit trail of role assignments

### Compliance
- Can demonstrate role-based access control
- Clear mapping between job functions and permissions
- Audit trail for role changes
- Separation of duties (External vs. Internal)

## Phase 2 Enhancements (Future)

**What Phase 2 Will Add**:
- Fine-grained permissions within services
- Resource-level access control
- Attribute-based policies
- Dynamic role assignment based on context

**How Groups/Roles Will Evolve**:
- Groups remain the same (External, Internal, Services)
- Business roles remain the same (User, Manager, Admin, Service)
- Additional permission claims added to tokens
- Services check both roles and permissions

**Example Phase 2 Token**:
```json
{
  "groups": ["Internal Users"],
  "realm_access": {
    "roles": ["Manager"]
  },
  "permissions": [
    "orders:read:own",
    "orders:read:team",
    "reports:read:all"
  ]
}
```

**Backward Compatibility**: Phase 1 service-level checks continue to work. Phase 2 adds additional granularity without breaking existing checks.

## Related Documentation

- [Simple Workflow Overview](./simple-workflow-overview.md) - Overall target design
- [Current State](../01-current-state/keycloak-overview.md) - What we're replacing
- [Migration Plan](../04-migration-plan/) - How to migrate from current to target

## Status

**Design Phase**: Initial - Phase 1 (Service-level access)
**Documented**: 2025-11-20
**Implementation Status**: Not yet started
**Review Status**: Pending stakeholder review
