# Migration Plan: Migration Phases

## Summary

This document defines the 6-phase migration plan for transitioning from the broken authorization model (Group A/B → service roles) to the target model (External/Internal/Services → business roles). Each phase has clear objectives, deliverables, success criteria, and rollback procedures.

**Total Duration**: 6-7 months (estimated)
**Approach**: Incremental, safe, with built-in rollback capability
**Zero Downtime**: Guaranteed through dual-mode operation

## Migration Overview

### Phase Sequence

```
Phase 0: Pre-Migration Preparation (Weeks 1-2)
   ↓
Phase 1: Keycloak Setup (Weeks 3-4)
   ↓
Phase 2: Dual-Mode Deployment (Weeks 5-12)
   ↓
Phase 3: User Migration (Weeks 13-20)
   ↓
Phase 4: Service Migration (Weeks 21-28)
   ↓
Phase 5: Cleanup (Weeks 29-30)
```

### Key Milestones

| Phase | Duration | Key Outcome |
|-------|----------|-------------|
| Phase 0 | 2 weeks | Current state documented, users mapped, test environments ready |
| Phase 1 | 2 weeks | New groups and business roles configured in Keycloak |
| Phase 2 | 8 weeks | All services support dual-mode authorization |
| Phase 3 | 8 weeks | All users migrated to new groups with business roles in tokens |
| Phase 4 | 8 weeks | All services use business role checks only (old checks removed) |
| Phase 5 | 2 weeks | Old groups/roles removed, migration complete |

**Total**: 30 weeks (7.5 months)

### Phase Dependencies

```
Phase 0 → Phase 1 (Cannot start Phase 1 without mapping data from Phase 0)
Phase 1 → Phase 2 (Cannot deploy dual-mode without new groups/roles)
Phase 2 → Phase 3 (Cannot migrate users until services support dual-mode)
Phase 3 → Phase 4 (Cannot drop old checks until all users migrated)
Phase 4 → Phase 5 (Cannot cleanup until all services use new model)
```

## Phase 0: Pre-Migration Preparation

### Objectives

1. Document current state completely
2. Map all existing users to target groups and roles
3. Set up test environments
4. Create migration tools and scripts
5. Train development teams

### Duration

**2 weeks**

### Deliverables

**Deliverable 1: Current State Audit**
- [ ] Export Keycloak realm configuration
- [ ] Document all existing groups (Group A, Group B, others)
- [ ] Document all existing service roles
- [ ] Capture sample tokens (anonymized)
- [ ] Document all 15+ microservices
- [ ] Identify service-to-service call patterns

**Deliverable 2: User Mapping**
- [ ] Extract all users from Keycloak
- [ ] Map users to target groups (External vs Internal vs Service accounts)
- [ ] Map business roles from app DB to Keycloak roles
- [ ] Identify edge cases (users with no business role, multiple roles, etc.)
- [ ] Create CSV mapping file for automated migration

**Example Mapping CSV**:
```csv
username,current_group,target_group,app_db_business_role,target_keycloak_role
alice@example.com,Group A,Internal Users,Manager,Manager
bob@company.com,Group B,Internal Users,User,User
charlie@customer.com,Group A,External Users,User,User
service-account-reporting,Group A,Services,NULL,Service
```

**Deliverable 3: Test Environment Setup**
- [ ] Clone production Keycloak to staging
- [ ] Clone subset of users to staging (anonymized)
- [ ] Deploy all 15+ services to staging
- [ ] Configure Kong gateway for staging
- [ ] Validate staging environment matches production

**Deliverable 4: Migration Tooling**
- [ ] Create Keycloak migration scripts (create groups, roles, mappers)
- [ ] Create user migration script (assign groups and roles)
- [ ] Create token inspector tool (validate token structure)
- [ ] Create authorization test suite (validate access)
- [ ] Document script usage

**Deliverable 5: Team Training**
- [ ] Document dual-mode pattern
- [ ] Create code examples for Spring Security dual-mode
- [ ] Conduct training sessions for dev teams
- [ ] Create migration playbook for service owners
- [ ] Set up Slack channel for migration questions

### Success Criteria

**Gate 0.1: Documentation Complete**
- [ ] All current state documented
- [ ] User mapping file covers 100% of users
- [ ] No unmapped edge cases

**Gate 0.2: Environment Ready**
- [ ] Staging environment functional
- [ ] Can deploy and test all services
- [ ] Kong gateway working

**Gate 0.3: Tooling Validated**
- [ ] Migration scripts tested in staging
- [ ] Token inspector working
- [ ] Authorization tests passing

**Gate 0.4: Team Ready**
- [ ] All dev teams trained on dual-mode
- [ ] Migration playbook reviewed
- [ ] Questions answered

### Risks and Mitigations

**Risk 1: Incomplete User Mapping**
- **Impact**: Users might be assigned wrong groups or roles
- **Mitigation**: Review mapping with business stakeholders, validate against LDAP/AD if available
- **Contingency**: Manual review of unmapped users

**Risk 2: Undocumented Services**
- **Impact**: Service might be missed in migration
- **Mitigation**: Cross-reference with deployment registry, network scanning
- **Contingency**: Rolling migration allows catching missed services

**Risk 3: Test Environment Drift**
- **Impact**: Staging doesn't match production, false confidence
- **Mitigation**: Automated sync from production, configuration management
- **Contingency**: Extra validation in production with canary deployments

### Timeline

| Week | Activities |
|------|------------|
| Week 1 | Current state audit, user mapping started |
| Week 2 | Test environment setup, tooling development, team training |

### Rollback

**N/A** - Phase 0 is read-only (no production changes)

## Phase 1: Keycloak Setup

### Objectives

1. Create new groups in Keycloak (External Users, Internal Users, Services)
2. Create new business roles in Keycloak (User, Manager, Admin, Service)
3. Configure role mappers for token inclusion
4. Validate configuration in staging
5. Deploy to production (configuration only, no user impact)

### Duration

**2 weeks**

### Deliverables

**Deliverable 1: Keycloak Groups**
Create new groups with descriptions:

```
Group: External Users
Description: Customers, partners, vendors, external contractors
Default Role: None (assigned manually)

Group: Internal Users
Description: Employees and internal staff
Default Role: None (assigned manually)

Group: Services
Description: Service accounts for machine-to-machine communication
Default Role: None (assigned manually)
```

**Deliverable 2: Keycloak Business Roles**
Create realm-level roles:

```
Role: User
Description: Standard user with basic permissions
Composite: false

Role: Manager
Description: Manager with reporting and team management permissions
Composite: false

Role: Admin
Description: System administrator with full access
Composite: false

Role: Service
Description: Service account role for inter-service communication
Composite: false
```

**Deliverable 3: Token Mappers**
Configure token mappers to include groups and roles:

```
Mapper 1: Groups Mapper
Type: Group Membership
Token Claim Name: groups
Full group path: false
Add to ID token: true
Add to access token: true
Add to userinfo: true

Mapper 2: Realm Roles Mapper
Type: User Realm Role
Multivalued: true
Token Claim Name: realm_access.roles
Claim JSON Type: String
Add to ID token: true
Add to access token: true
Add to userinfo: false
```

**Deliverable 4: Service Access Matrix**
Define which business roles grant access to which services (Phase 1 - service-level):

```
User Service:
  - User: read/write own data
  - Manager: read team data
  - Admin: full access
  - Service: full access

Order Service:
  - User: read/write own orders
  - Manager: read team orders
  - Admin: full access
  - Service: full access

Payment Service:
  - User: process own payments
  - Manager: view team payment reports
  - Admin: full access
  - Service: full access

Reporting Service:
  - User: no access
  - Manager: read reports
  - Admin: full access
  - Service: read reports

Admin Service:
  - User: no access
  - Manager: no access
  - Admin: full access
  - Service: no access
```

**Deliverable 5: Staging Validation**
- [ ] Deploy Keycloak changes to staging
- [ ] Create test users in each group with each role
- [ ] Generate tokens and inspect claims
- [ ] Validate token structure includes groups and roles
- [ ] Test tokens against staging services (should be rejected initially - services not updated yet)

**Deliverable 6: Production Deployment**
- [ ] Export Keycloak configuration from staging
- [ ] Review with security team
- [ ] Deploy to production Keycloak
- [ ] Validate groups and roles exist
- [ ] Generate test token (test user only)

### Success Criteria

**Gate 1.1: Groups Created**
- [ ] External Users, Internal Users, Services groups exist
- [ ] Group descriptions accurate
- [ ] Groups visible in Keycloak admin console

**Gate 1.2: Roles Created**
- [ ] User, Manager, Admin, Service roles exist
- [ ] Roles are realm-level (not client-level)
- [ ] Role descriptions accurate

**Gate 1.3: Token Mappers Configured**
- [ ] Groups mapper includes groups in token
- [ ] Roles mapper includes realm_access.roles in token
- [ ] Test token contains expected claims

**Gate 1.4: Staging Validated**
- [ ] Test users assigned to groups and roles
- [ ] Tokens generated successfully
- [ ] Token structure matches expected format

**Gate 1.5: Production Deployed**
- [ ] Configuration deployed to production
- [ ] No impact to existing users (old groups/roles unchanged)
- [ ] Test user can generate token with new claims

### Risks and Mitigations

**Risk 1: Token Structure Breaks Services**
- **Impact**: Services might reject new token structure
- **Mitigation**: Phase 1 only adds new claims, doesn't remove old claims
- **Contingency**: New groups/roles exist but not assigned to users yet

**Risk 2: Token Size Exceeds Limits**
- **Impact**: Tokens too large for HTTP headers or storage
- **Mitigation**: Monitor token size in staging, use compression if needed
- **Contingency**: Reduce claims or use reference tokens

**Risk 3: Keycloak Configuration Error**
- **Impact**: Tokens missing expected claims
- **Mitigation**: Thorough staging validation before production
- **Contingency**: Rollback Keycloak configuration

### Timeline

| Week | Activities |
|------|------------|
| Week 3 | Create groups, roles, and mappers in staging; validate |
| Week 4 | Deploy to production, final validation |

### Rollback

**Rollback Procedure**:
1. Delete new groups (External Users, Internal Users, Services) from production
2. Delete new roles (User, Manager, Admin, Service) from production
3. Remove token mappers

**Rollback Time**: <1 hour

**Data Loss**: None (no users assigned to new groups yet)

## Phase 2: Dual-Mode Deployment

### Objectives

1. Update all 15+ microservices to support dual-mode authorization
2. Deploy dual-mode services to production
3. Validate backward compatibility (old tokens still work)
4. Prepare for user migration

### Duration

**8 weeks** (assuming 2 services per week)

### Deliverables

**Deliverable 1: Dual-Mode Code Pattern**
Standard pattern for all services:

```java
// Before (Old Model)
@PreAuthorize("hasRole('order-service-role')")
@GetMapping("/api/orders")
public List<Order> getOrders() {
    return orderService.findOrders();
}

// After (Dual-Mode)
@PreAuthorize("hasRole('order-service-role') or hasRole('USER') or hasRole('MANAGER') or hasRole('ADMIN')")
@GetMapping("/api/orders")
public List<Order> getOrders() {
    return orderService.findOrders();
}
```

**Deliverable 2: Dual-Mode Feature Flag**
Add feature flag to enable/disable dual-mode per service:

```yaml
# application.yml
authorization:
  dualMode:
    enabled: true  # Set to false for rollback
```

```java
@Service
public class AuthorizationService {

    @Value("${authorization.dualMode.enabled:false}")
    private boolean dualModeEnabled;

    public boolean hasAccess(Authentication auth, String requiredRole) {
        if (dualModeEnabled) {
            return hasOldRole(auth, requiredRole) || hasBusinessRole(auth, requiredRole);
        } else {
            return hasOldRole(auth, requiredRole);
        }
    }
}
```

**Deliverable 3: Service Migration Order**
Prioritize low-risk services first:

**Wave 1 (Weeks 5-6): Non-Critical Services**
- notification-service (low risk, limited data)
- audit-service (read-only for most users)

**Wave 2 (Weeks 7-8): Customer-Facing Services**
- customer-service
- user-service

**Wave 3 (Weeks 9-10): Core Business Services**
- order-service
- payment-service
- inventory-service

**Wave 4 (Weeks 11-12): Admin and Integration Services**
- admin-service
- reporting-service
- analytics-service
- integration-service
- billing-service
- shipping-service

**Deliverable 4: Service Deployment Process**
For each service:
1. Update `@PreAuthorize` annotations to dual-mode
2. Add feature flag configuration
3. Test in local environment with old and new tokens
4. Deploy to staging
5. Run authorization test suite
6. Deploy to production (feature flag off initially)
7. Enable feature flag (canary: 10% → 50% → 100%)
8. Monitor for authorization errors
9. Move to next service

**Deliverable 5: Monitoring and Alerting**
- [ ] Set up authorization error metrics per service
- [ ] Configure alerts for error rate spikes
- [ ] Create dashboard for dual-mode rollout progress
- [ ] Set up log aggregation for authorization failures

### Success Criteria

**Gate 2.1: First Service Deployed**
- [ ] First service accepts old tokens
- [ ] First service accepts new tokens (test user)
- [ ] No authorization errors in production
- [ ] Feature flag rollback tested

**Gate 2.2: All Services Deployed**
- [ ] All 15+ services in dual-mode
- [ ] All services accept old tokens (validated)
- [ ] All services accept new tokens (test users)
- [ ] No authorization errors across all services

**Gate 2.3: Backward Compatibility Validated**
- [ ] Old tokens work across all services
- [ ] No users impacted by dual-mode deployment
- [ ] Performance metrics within acceptable range

**Gate 2.4: Ready for User Migration**
- [ ] All services stable in dual-mode
- [ ] Rollback tested and successful
- [ ] User migration scripts tested in staging

### Risks and Mitigations

**Risk 1: Authorization Logic Bug**
- **Impact**: Service incorrectly grants or denies access
- **Mitigation**: Thorough testing with both old and new tokens
- **Contingency**: Feature flag rollback for affected service

**Risk 2: Performance Degradation**
- **Impact**: Dual authorization checks slow down requests
- **Mitigation**: Monitor latency metrics, optimize if needed
- **Contingency**: Investigate and optimize, or rollback if severe

**Risk 3: Service Deployment Failure**
- **Impact**: Service unavailable during deployment
- **Mitigation**: Use blue-green or canary deployment
- **Contingency**: Rollback deployment, investigate issue

### Timeline

| Week | Services Migrated | Cumulative Progress |
|------|-------------------|---------------------|
| Week 5 | notification-service | 1/15 (7%) |
| Week 6 | audit-service | 2/15 (13%) |
| Week 7 | customer-service, user-service | 4/15 (27%) |
| Week 8 | (buffer week for issues) | 4/15 (27%) |
| Week 9 | order-service, payment-service | 6/15 (40%) |
| Week 10 | inventory-service | 7/15 (47%) |
| Week 11 | admin-service, reporting-service, analytics-service | 10/15 (67%) |
| Week 12 | integration-service, billing-service, shipping-service, others | 15/15 (100%) |

### Rollback

**Per-Service Rollback**:
1. Disable feature flag: `authorization.dualMode.enabled=false`
2. Service reverts to checking only old service roles
3. Redeploy if feature flag change requires restart

**Rollback Time**: <30 minutes per service

**All-Services Rollback**:
1. Disable feature flag across all services
2. Use Kubernetes ConfigMap update or environment variable change

**Rollback Time**: <1 hour for all services

**Data Loss**: None (no data changes in Phase 2)

## Phase 3: User Migration

### Objectives

1. Migrate all users from old groups (Group A/B) to new groups (External/Internal/Services)
2. Assign business roles to users in Keycloak
3. Ensure tokens include both old and new claims during transition
4. Validate no access is lost

### Duration

**8 weeks** (gradual rollout, 12.5% of users per week)

### Deliverables

**Deliverable 1: User Migration Script**
Automated script to migrate users:

```python
# migrate_users.py
import csv
from keycloak import KeycloakAdmin

keycloak_admin = KeycloakAdmin(
    server_url="https://keycloak.example.com/auth/",
    username="admin",
    password="admin_password",
    realm_name="james-realm"
)

def migrate_user(username, target_group, target_role):
    """Migrate a single user to new group and role."""
    try:
        # Get user
        user = keycloak_admin.get_user_id(username)

        # Assign to new group (keep old group membership)
        keycloak_admin.group_user_add(user, target_group)

        # Assign business role
        role = keycloak_admin.get_realm_role(target_role)
        keycloak_admin.assign_realm_roles(user, [role])

        print(f"✓ Migrated {username} to {target_group} with role {target_role}")
        return True
    except Exception as e:
        print(f"✗ Failed to migrate {username}: {str(e)}")
        return False

def migrate_from_csv(csv_file):
    """Migrate all users from CSV mapping file."""
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            migrate_user(
                username=row['username'],
                target_group=row['target_group'],
                target_role=row['target_keycloak_role']
            )

if __name__ == "__main__":
    migrate_from_csv('user_mapping.csv')
```

**Deliverable 2: Migration Waves**
Gradual rollout to reduce risk:

**Wave 1 (Week 13): Test Users (1%)**
- Migrate handful of test users
- Validate tokens include both old and new claims
- Test access to all services

**Wave 2 (Week 14): Internal IT Staff (5%)**
- Migrate IT department users
- Users are technical and can provide feedback
- Validate no issues before broader rollout

**Wave 3 (Week 15): Low-Risk User Segment (10%)**
- Migrate read-only users or non-critical department
- Monitor support tickets for access issues

**Wave 4 (Week 16): Service Accounts (All service accounts)**
- Migrate all service accounts to Services group
- Validate inter-service communication still works

**Wave 5 (Weeks 17-19): Internal Users (40%)**
- Migrate employees in phases
- 15% per week

**Wave 6 (Weeks 20): External Users (Remaining ~44%)**
- Migrate customers, partners, vendors
- Communicate with external users if needed

**Deliverable 3: Token Validation**
After each migration wave:
- [ ] Generate token for migrated user
- [ ] Inspect token claims
- [ ] Verify old claims still present (Group A/B, service roles)
- [ ] Verify new claims present (External/Internal/Services, business roles)
- [ ] Test access to all services

**Expected Token Structure During Phase 3**:
```json
{
  "sub": "user-123",
  "preferred_username": "alice@example.com",
  "groups": [
    "Group A",           // OLD: Still present for backward compat
    "Internal Users"     // NEW: Added during migration
  ],
  "realm_access": {
    "roles": [
      "user-service-role",    // OLD: Still present
      "order-service-role",   // OLD: Still present
      "payment-service-role", // OLD: Still present
      // ... (other old service roles)
      "Manager"               // NEW: Business role from Keycloak
    ]
  }
}
```

**Deliverable 4: Access Validation Test Suite**
Automated tests to validate no access lost:

```python
# test_user_access.py
import requests

def test_user_access(username, password, services):
    """Test user can access all expected services."""
    # Authenticate
    token = get_token(username, password)

    # Test each service
    results = {}
    for service in services:
        try:
            response = requests.get(
                f"https://api.example.com/{service}/health",
                headers={"Authorization": f"Bearer {token}"}
            )
            results[service] = response.status_code == 200
        except Exception as e:
            results[service] = False
            print(f"Error accessing {service}: {str(e)}")

    return results

# Run for migrated users
test_user_access("alice@example.com", "password", [
    "user-service",
    "order-service",
    "payment-service",
    # ... all services user should access
])
```

**Deliverable 5: Migration Dashboard**
Real-time dashboard showing:
- % of users migrated
- % of users by group (External, Internal, Services)
- % of users by role (User, Manager, Admin, Service)
- Authorization error rate
- Support ticket volume

### Success Criteria

**Gate 3.1: Test Users Migrated**
- [ ] Test users have tokens with both old and new claims
- [ ] Test users can access all expected services
- [ ] No authorization errors for test users

**Gate 3.2: IT Staff Migrated**
- [ ] IT staff migrated successfully
- [ ] No feedback about access issues
- [ ] Validation tests passing

**Gate 3.3: Service Accounts Migrated**
- [ ] All service accounts in Services group
- [ ] Inter-service communication working
- [ ] No service-to-service authorization errors

**Gate 3.4: All Users Migrated**
- [ ] 100% of users assigned to new groups
- [ ] 100% of users have business roles in Keycloak
- [ ] No access lost (validation tests passing)
- [ ] Support ticket volume normal

**Gate 3.5: Dual Claims Validated**
- [ ] All user tokens include both old and new claims
- [ ] Token size acceptable (<8KB)
- [ ] Services accept all tokens

### Risks and Mitigations

**Risk 1: User Assigned Wrong Group**
- **Impact**: User has incorrect permissions
- **Mitigation**: Review mapping with stakeholders, validate in staging
- **Contingency**: Manual correction, or rollback migration for that user

**Risk 2: User Assigned Wrong Role**
- **Impact**: User has too much or too little access
- **Mitigation**: Cross-reference with app DB business roles
- **Contingency**: Update role assignment in Keycloak

**Risk 3: Token Size Exceeds Limit**
- **Impact**: Tokens rejected by services or gateways
- **Mitigation**: Monitor token size, enable compression if needed
- **Contingency**: Reduce claims or delay cleanup phase

**Risk 4: Mass Access Loss**
- **Impact**: Many users lose access simultaneously
- **Mitigation**: Gradual rollout, validation after each wave
- **Contingency**: Rollback user migration, disable dual-mode

### Timeline

| Week | User Segment | % Migrated | Cumulative |
|------|--------------|------------|------------|
| Week 13 | Test users | 1% | 1% |
| Week 14 | IT staff | 5% | 6% |
| Week 15 | Low-risk segment | 10% | 16% |
| Week 16 | Service accounts | 3% | 19% |
| Week 17 | Internal users (batch 1) | 15% | 34% |
| Week 18 | Internal users (batch 2) | 15% | 49% |
| Week 19 | Internal users (batch 3) | 10% | 59% |
| Week 20 | External users | 41% | 100% |

### Rollback

**Per-User Rollback**:
1. Remove user from new group (External/Internal/Services)
2. Remove business role from user
3. User's token reverts to old structure on next login
4. User access restored via old authorization checks

**Rollback Time**: <5 minutes per user

**Batch Rollback**:
1. Run rollback script to remove group/role for batch of users
2. Users revert to old token structure on next login

**Rollback Time**: <1 hour for batch

**All-Users Rollback**:
1. Disable dual-mode feature flags (revert to old authorization only)
2. Users keep new group/role assignments (harmless, ignored by services)
3. Optional: Remove all new group/role assignments (can be done later)

**Rollback Time**: <1 hour for feature flag disable

**Data Loss**: None (old groups/roles remain, can reassign if needed)

## Phase 4: Service Migration

### Objectives

1. Remove old authorization checks from all services
2. Services check only business roles (User, Manager, Admin, Service)
3. Remove dependency on old service roles in tokens
4. Validate all services work with new authorization only

### Duration

**8 weeks** (2 services per week, includes grace period)

### Deliverables

**Deliverable 1: Updated Authorization Pattern**
Remove old service role checks:

```java
// Before (Dual-Mode)
@PreAuthorize("hasRole('order-service-role') or hasRole('USER') or hasRole('MANAGER') or hasRole('ADMIN')")
@GetMapping("/api/orders")
public List<Order> getOrders() {
    return orderService.findOrders();
}

// After (New Model Only)
@PreAuthorize("hasRole('USER') or hasRole('MANAGER') or hasRole('ADMIN')")
@GetMapping("/api/orders")
public List<Order> getOrders() {
    return orderService.findOrders();
}
```

**Deliverable 2: Remove Business Role DB Queries**
Services stop querying app database for business roles:

```java
// Before (Dual-Source)
public BusinessRole getBusinessRole(Authentication auth) {
    // Try Keycloak token first
    Optional<BusinessRole> keycloakRole = extractFromToken(auth);
    if (keycloakRole.isPresent()) {
        return keycloakRole.get();
    }

    // Fall back to app database
    return userRepository.findBusinessRoleByUsername(auth.getName());
}

// After (Keycloak Only)
public BusinessRole getBusinessRole(Authentication auth) {
    // Get from Keycloak token only
    return extractFromToken(auth)
        .orElseThrow(() -> new AuthorizationException("Business role not found in token"));
}
```

**Deliverable 3: Service Migration Order**
Same order as Phase 2 (low-risk first):

**Wave 1 (Weeks 21-22): Non-Critical Services**
- notification-service
- audit-service

**Wave 2 (Weeks 23-24): Customer-Facing Services**
- customer-service
- user-service

**Wave 3 (Weeks 25-26): Core Business Services**
- order-service
- payment-service
- inventory-service

**Wave 4 (Weeks 27-28): Admin and Integration Services**
- admin-service
- reporting-service
- analytics-service
- integration-service
- billing-service
- shipping-service

**Deliverable 4: Service Deployment Process**
For each service:
1. Remove old authorization checks from code
2. Remove feature flag (no longer needed)
3. Test in local environment with new tokens only
4. Deploy to staging
5. Run authorization test suite (should use new roles only)
6. Deploy to production (canary: 10% → 50% → 100%)
7. Monitor for authorization errors
8. **Grace period**: Wait 1 week before migrating next service
9. Move to next service

**Deliverable 5: Grace Period Validation**
After each service migration, wait 1 week and validate:
- [ ] No authorization errors in production
- [ ] Service metrics within normal range
- [ ] No support tickets related to access issues
- [ ] Service only checks business roles (log analysis)

### Success Criteria

**Gate 4.1: First Service Migrated**
- [ ] First service checks only business roles
- [ ] No old authorization checks remain
- [ ] Grace period (1 week) passed with no issues

**Gate 4.2: All Services Migrated**
- [ ] All 15+ services check only business roles
- [ ] No services query app DB for business roles
- [ ] All authorization tests passing

**Gate 4.3: Grace Period Complete**
- [ ] 4+ weeks since last service migrated
- [ ] No authorization errors in production
- [ ] All services stable

**Gate 4.4: Ready for Cleanup**
- [ ] All services confirmed using new authorization
- [ ] Old authorization checks completely removed from codebase
- [ ] Stakeholder approval for Phase 5 (cleanup)

### Risks and Mitigations

**Risk 1: Service Breaks After Removing Old Checks**
- **Impact**: Service denies access to legitimate users
- **Mitigation**: Thorough testing in staging before production
- **Contingency**: Rollback deployment (redeploy with old checks)

**Risk 2: Edge Case User Without Business Role**
- **Impact**: User loses access after service migration
- **Mitigation**: Validate all users have business roles before Phase 4
- **Contingency**: Assign business role to user, or rollback service

**Risk 3: Hidden Dependency on Old Authorization**
- **Impact**: Service feature breaks due to unexpected dependency
- **Mitigation**: Code review to find all authorization checks
- **Contingency**: Add business role check for that feature

### Timeline

| Week | Services Migrated | Cumulative Progress |
|------|-------------------|---------------------|
| Week 21 | notification-service | 1/15 (7%) |
| Week 22 | audit-service | 2/15 (13%) |
| Week 23 | customer-service | 3/15 (20%) |
| Week 24 | user-service | 4/15 (27%) |
| Week 25 | order-service, payment-service | 6/15 (40%) |
| Week 26 | inventory-service | 7/15 (47%) |
| Week 27 | admin-service, reporting-service, analytics-service | 10/15 (67%) |
| Week 28 | integration-service, billing-service, shipping-service, others | 15/15 (100%) |
| Weeks 29-30 | Grace period (4 weeks total) | 100% |

### Rollback

**Per-Service Rollback**:
1. Redeploy service with dual-mode code (Phase 2 version)
2. Enable feature flag for dual-mode
3. Service accepts both old and new authorization again

**Rollback Time**: 1-2 hours per service (code deployment)

**All-Services Rollback**:
1. Redeploy all services with dual-mode code
2. Enable feature flags across all services

**Rollback Time**: 4-8 hours for all services (parallel deployments)

**Data Loss**: None (user tokens still contain both old and new claims)

**Note**: After Phase 4, rollback becomes more difficult because tokens will eventually lose old claims (Phase 5 cleanup). Must complete Phase 4 rollback before Phase 5 begins.

## Phase 5: Cleanup

### Objectives

1. Remove old groups (Group A, Group B) from Keycloak
2. Remove old service roles from Keycloak
3. Remove business role tables from application databases
4. Remove old authorization code completely
5. Reduce token size to target

### Duration

**2 weeks**

### Deliverables

**Deliverable 1: Remove Old Groups**
- [ ] Remove users from Group A and Group B
- [ ] Delete Group A and Group B from Keycloak
- [ ] Validate users only belong to External/Internal/Services groups

**Deliverable 2: Remove Old Service Roles**
- [ ] Remove service role mappings from groups
- [ ] Delete service roles from Keycloak realm
- [ ] Validate roles no longer in token

**Deliverable 3: Remove Business Role DB Tables**
For each microservice with business role tables:
- [ ] Backup app database
- [ ] Drop business role tables (users.business_role, role_assignments, etc.)
- [ ] Remove repository/DAO code for business roles
- [ ] Remove any remaining queries to business role tables

**Deliverable 4: Remove Old Authorization Code**
- [ ] Remove feature flags for dual-mode
- [ ] Remove dual-source business role resolution code
- [ ] Remove old authorization utility methods
- [ ] Clean up unused imports and dependencies

**Deliverable 5: Token Structure Validation**
After cleanup, validate token structure:

```json
{
  "sub": "user-123",
  "preferred_username": "alice@example.com",
  "email": "alice@example.com",
  "groups": ["Internal Users"],  // Only new group
  "realm_access": {
    "roles": ["Manager"]  // Only business role, no service roles
  }
}
```

**Expected token size**: 1-2KB (significantly smaller than Phase 3)

**Deliverable 6: Final Validation**
- [ ] All users have only new groups
- [ ] All users have business roles in Keycloak
- [ ] All services check only business roles
- [ ] Token size within target range
- [ ] Authorization tests passing across all services
- [ ] Support ticket volume normal

### Success Criteria

**Gate 5.1: Old Groups Removed**
- [ ] Group A and Group B deleted from Keycloak
- [ ] No users assigned to old groups
- [ ] Tokens no longer include old groups

**Gate 5.2: Old Roles Removed**
- [ ] Service roles deleted from Keycloak
- [ ] Tokens no longer include service roles
- [ ] Token size reduced significantly

**Gate 5.3: App DB Cleaned**
- [ ] Business role tables removed from all service databases
- [ ] No code references business role tables
- [ ] Services only read business roles from tokens

**Gate 5.4: Code Cleaned**
- [ ] All dual-mode code removed
- [ ] All feature flags removed
- [ ] Codebase uses only new authorization pattern

**Gate 5.5: Migration Complete**
- [ ] All success criteria met
- [ ] No authorization errors for 2+ weeks
- [ ] Stakeholder sign-off

### Risks and Mitigations

**Risk 1: Premature Cleanup**
- **Impact**: Services break if old authorization still needed
- **Mitigation**: Wait 4+ weeks after Phase 4 before starting Phase 5
- **Contingency**: Restore from backup (complex, time-consuming)

**Risk 2: Backup Restoration Needed**
- **Impact**: Must restore old groups/roles from backup
- **Mitigation**: Take comprehensive backups before cleanup
- **Contingency**: Manual recreation of old groups/roles (days of work)

**Risk 3: Token Size Doesn't Decrease**
- **Impact**: Token still large after cleanup
- **Mitigation**: Validate token structure after each cleanup step
- **Contingency**: Investigate additional claims, work with Keycloak team

### Timeline

| Week | Activities |
|------|------------|
| Week 29 | Remove old groups and roles from Keycloak; validate tokens |
| Week 30 | Remove business role DB tables; remove old code; final validation |

### Rollback

**Rollback Difficulty**: HARD (cannot rollback Phase 5 once complete)

**Why Rollback Is Hard**:
- Old groups and roles deleted (must recreate)
- App DB tables dropped (must restore from backup)
- Old authorization code removed (must redeploy old code)

**Rollback Procedure** (if absolutely necessary):
1. Restore Keycloak realm from backup (includes old groups/roles)
2. Restore app databases from backup (includes business role tables)
3. Redeploy services with dual-mode code (Phase 2 version)
4. Reassign users to Group A/B (based on backup data)

**Rollback Time**: 1-3 days (complex restoration)

**Data Loss**: Potential loss of any changes made after backups taken

**Prevention**: Wait 4+ weeks after Phase 4 and get executive approval before starting Phase 5.

## Cross-Phase Concerns

### Communication Plan

**Before Each Phase**:
- Email all stakeholders with phase objectives and timeline
- Post to Slack channel for migration updates
- Update migration dashboard with phase status

**During Each Phase**:
- Daily updates on progress
- Immediate notification of any issues
- Weekly summary reports

**After Each Phase**:
- Phase completion announcement
- Success metrics report
- Lessons learned document

### Monitoring and Alerting

**Key Metrics**:
- Authorization error rate (per service)
- Token size (average and max)
- User migration progress (%)
- Service migration progress (%)
- Support ticket volume

**Alerts**:
- Authorization error rate spike (>5% increase)
- Service deployment failure
- Token size exceeds 8KB
- User unable to authenticate

### Documentation Updates

**After Phase 0**:
- [ ] Update current state documentation with audit findings

**After Phase 1**:
- [ ] Document Keycloak configuration
- [ ] Update architecture diagrams

**After Phase 2**:
- [ ] Document dual-mode pattern
- [ ] Create service migration playbook

**After Phase 3**:
- [ ] Document user migration process
- [ ] Update token structure documentation

**After Phase 4**:
- [ ] Update service authorization examples
- [ ] Remove old authorization references

**After Phase 5**:
- [ ] Final architecture documentation
- [ ] Post-migration report
- [ ] Lessons learned

## Success Metrics

**Technical Success**:
- Zero downtime during migration
- No authorization errors in production
- Token size reduced by 60-80%
- All services migrated successfully

**Business Success**:
- No user complaints about access issues
- No increase in support tickets
- Compliance requirements met
- Improved security posture

**Team Success**:
- All dev teams trained on new authorization
- Migration completed on schedule
- Rollback capability maintained throughout
- Knowledge transfer to operations team

## Related Documentation

- [Backward Compatibility Strategy](../03-target-design/backward-compatibility.md) - Dual-mode details
- [Rollback Strategy](./rollback-strategy.md) - Comprehensive rollback procedures
- [Testing Strategy](./testing-strategy.md) - How to test each phase
- [Simple Workflow Overview](../03-target-design/simple-workflow-overview.md) - Target design

## Status

**Documented**: 2025-11-20
**Total Duration**: 30 weeks (7.5 months)
**Risk Level**: Low (with phased approach and rollback capability)
**Approval Status**: Pending stakeholder review
