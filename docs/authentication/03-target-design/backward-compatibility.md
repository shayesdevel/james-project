# Target Design: Backward Compatibility Strategy

## Summary

This document defines the backward compatibility strategy for migrating from the current broken authorization model (Group A/B → dozens of service roles) to the target model (External/Internal/Services groups → business roles → service access). The strategy enables running BOTH models simultaneously during the transition, ensuring zero downtime and safe rollback capability.

**Core Principle**: Support dual-mode authorization where services check BOTH old and new authorization patterns, allowing services and users to migrate independently without disrupting each other.

## Migration Challenge

### Current State
```
User → Group A/B (auto-assigned)
     ↓
Dozens of service roles (user-service-role, order-service-role, etc.)
     ↓
Business roles (User, Manager, Admin) in app database
     ↓
Spring Security: hasRole('service-x-role') + custom DB queries
```

### Target State
```
User → External/Internal/Services group (explicitly assigned)
     ↓
Business role (User, Manager, Admin) in Keycloak token
     ↓
Service-level access based on business role
     ↓
Spring Security: hasRole('USER') or hasRole('MANAGER') or hasRole('ADMIN')
```

### The Problem
- **15+ microservices** need to migrate independently
- **Cannot migrate all at once** (too risky, too complex)
- **Users migrate gradually** (external vs internal assignment, role mapping)
- **Tokens must work during transition** (old tokens with new services, new tokens with old services)
- **Zero downtime requirement** (business cannot stop)
- **Rollback must be possible** (if migration fails)

## Backward Compatibility Requirements

### Requirement 1: Token Compatibility
**Requirement**: Tokens must work with services using EITHER old OR new authorization model.

**How It Works**:
- **Old tokens**: Include Group A/B + dozens of service roles (no business roles yet)
- **New tokens**: Include External/Internal/Services groups + business roles (User/Manager/Admin)
- **Transition tokens**: Include BOTH old and new role claims during migration

**Token Structure During Migration**:
```json
{
  "sub": "user-123",
  "preferred_username": "alice@example.com",
  "email": "alice@example.com",
  "groups": [
    "Group A",           // OLD: Keep for backward compat
    "Internal Users"     // NEW: Added during migration
  ],
  "realm_access": {
    "roles": [
      "user-service-role",    // OLD: Keep for backward compat
      "order-service-role",   // OLD: Keep for backward compat
      "payment-service-role", // OLD: Keep for backward compat
      // ... (other service roles)
      "Manager"               // NEW: Business role in Keycloak
    ]
  }
}
```

**Key Insight**: Tokens contain BOTH old and new claims. Services choose which to check based on their migration status.

### Requirement 2: Dual Role Checking
**Requirement**: Spring Security must check BOTH old (service roles) AND new (business roles) authorization patterns.

**How It Works**:
- Services that haven't migrated: Check for `service-x-role`
- Services that have migrated: Check for business roles (`USER`, `MANAGER`, `ADMIN`)
- During transition: Services check BOTH patterns (accept either)

**Spring Security Pattern - Dual Mode**:
```java
// Phase 2 (Dual-Mode): Accept BOTH old service role AND new business role
@PreAuthorize("hasRole('order-service-role') or hasRole('USER') or hasRole('MANAGER') or hasRole('ADMIN')")
@GetMapping("/api/orders")
public List<Order> getOrders() {
    // Service accepts old OR new authorization
    return orderService.findOrders();
}
```

**Why This Works**:
- Old tokens with `order-service-role`: Pass the check
- New tokens with `Manager` role: Pass the check
- Hybrid tokens with both: Pass the check (redundant but safe)
- Services work regardless of user's migration status

### Requirement 3: Business Role Source Flexibility
**Requirement**: Services must handle business roles from EITHER Keycloak token OR app database.

**How It Works**:
- **Phase 0 (Current)**: Business roles in app DB only
- **Phase 2 (Transition)**: Check Keycloak token FIRST, fall back to app DB if not present
- **Phase 5 (Target)**: Business roles in Keycloak only, app DB removed

**Dual-Source Business Role Check** (Pseudocode):
```java
public String getUserBusinessRole(Authentication auth) {
    // Try to get business role from Keycloak token (new way)
    Optional<String> keycloakRole = extractBusinessRoleFromToken(auth);
    if (keycloakRole.isPresent()) {
        return keycloakRole.get();  // User has migrated
    }

    // Fall back to app database (old way)
    return userRepository.findBusinessRoleByUsername(auth.getName());
}
```

**Why This Works**:
- Migrated users: Business role in token (fast, no DB query)
- Non-migrated users: Business role from DB (legacy behavior)
- Services work for ALL users regardless of migration status

### Requirement 4: Group Assignment Coexistence
**Requirement**: Users can belong to BOTH old groups (Group A/B) AND new groups (External/Internal/Services) during transition.

**How It Works**:
- User starts with Group A or Group B
- When migrated: User assigned to External Users OR Internal Users (keep old group membership)
- Old services check for Group A/B (still works)
- New services check for External/Internal/Services (works)
- After full migration: Remove Group A/B membership

**Group Membership During Migration**:
```
User "alice@example.com"
├─ Group A              // OLD: Keep for backward compat
└─ Internal Users       // NEW: Added during migration

Token includes both groups:
{
  "groups": ["Group A", "Internal Users"]
}
```

### Requirement 5: Service Role Compatibility
**Requirement**: Service roles remain in tokens during transition, even after business roles are added.

**How It Works**:
- Keycloak continues to include service roles in tokens (Group A/B mappings remain active)
- Business roles added to tokens via new role assignments
- Services that haven't migrated: Check service roles (still work)
- Services that have migrated: Check business roles (work too)
- After full migration: Remove service role mappings

**Why This Works**:
- No service is disrupted during migration
- Each service migrates on its own timeline
- Token size increases temporarily (acceptable trade-off for safety)

## Dual-Mode Operation (Phase 2)

### What Is Dual-Mode?
**Dual-mode** is the transition state where the system supports BOTH old and new authorization models simultaneously.

**Duration**: From first user migration until last service migrates (estimated 3-6 months)

**Characteristics**:
- All tokens contain both old and new claims
- All services check both old and new authorization patterns
- Business roles available from both Keycloak and app DB
- Users belong to both old and new groups

### Enabling Dual-Mode in Services

**Step 1: Add Business Role Checks**
Update `@PreAuthorize` annotations to accept BOTH old service roles AND new business roles:

```java
// BEFORE (Old Model Only)
@PreAuthorize("hasRole('order-service-role')")
@GetMapping("/api/orders")
public List<Order> getOrders() {
    return orderService.findOrders();
}

// AFTER (Dual-Mode)
@PreAuthorize("hasRole('order-service-role') or hasRole('USER') or hasRole('MANAGER') or hasRole('ADMIN')")
@GetMapping("/api/orders")
public List<Order> getOrders() {
    return orderService.findOrders();
}
```

**Step 2: Add Dual-Source Business Role Resolution**
If service needs to check business roles (not just service access):

```java
@Service
public class AuthorizationService {

    @Autowired
    private UserRepository userRepository;

    public BusinessRole getBusinessRole(Authentication auth) {
        // Try Keycloak token first (new way)
        Optional<BusinessRole> keycloakRole = extractFromToken(auth);
        if (keycloakRole.isPresent()) {
            return keycloakRole.get();
        }

        // Fall back to app database (old way)
        String username = auth.getName();
        return userRepository.findBusinessRoleByUsername(username);
    }

    private Optional<BusinessRole> extractFromToken(Authentication auth) {
        if (auth instanceof JwtAuthenticationToken) {
            Jwt jwt = ((JwtAuthenticationToken) auth).getToken();
            List<String> realmRoles = jwt.getClaimAsStringList("realm_access.roles");

            // Check for business roles in token
            if (realmRoles.contains("ADMIN")) return Optional.of(BusinessRole.ADMIN);
            if (realmRoles.contains("MANAGER")) return Optional.of(BusinessRole.MANAGER);
            if (realmRoles.contains("USER")) return Optional.of(BusinessRole.USER);
        }
        return Optional.empty();
    }
}
```

**Step 3: Update Spring Security Configuration**
Configure Spring Security to handle both JWT claims structures:

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                )
            );
        return http.build();
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(new DualModeAuthoritiesConverter());
        return converter;
    }

    // Custom converter that extracts BOTH old service roles and new business roles
    public class DualModeAuthoritiesConverter implements Converter<Jwt, Collection<GrantedAuthority>> {
        @Override
        public Collection<GrantedAuthority> convert(Jwt jwt) {
            Set<GrantedAuthority> authorities = new HashSet<>();

            // Extract realm_access.roles (contains both old service roles and new business roles)
            Map<String, Object> realmAccess = jwt.getClaimAsMap("realm_access");
            if (realmAccess != null && realmAccess.containsKey("roles")) {
                List<String> roles = (List<String>) realmAccess.get("roles");
                for (String role : roles) {
                    authorities.add(new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()));
                }
            }

            // Extract groups (both old Group A/B and new External/Internal/Services)
            List<String> groups = jwt.getClaimAsStringList("groups");
            if (groups != null) {
                for (String group : groups) {
                    authorities.add(new SimpleGrantedAuthority("GROUP_" + group.toUpperCase()));
                }
            }

            return authorities;
        }
    }
}
```

### Token Size Considerations

**During Dual-Mode**:
- Token size increases (both old and new claims)
- Old model: ~15-20 service roles per user
- New model: 3-4 business roles per user
- Dual-mode: ~18-24 roles total (temporary)

**Impact**:
- Increased token size affects network bandwidth slightly
- Still within JWT size limits (typically <8KB)
- Acceptable trade-off for safe migration
- Returns to normal after migration completes

**Mitigation**:
- Remove service roles progressively as services migrate
- Monitor token size during migration
- Use token compression if available (Keycloak supports)

## Grace Period Strategy

### What Is the Grace Period?
**Grace Period**: The time window during which BOTH old and new authorization models are supported in production.

**Purpose**:
- Allow services to migrate at their own pace
- Provide buffer for testing and validation
- Enable rollback if issues are discovered
- Reduce pressure on migration timeline

### Grace Period Timeline

**Phase 2 Start**: Dual-mode enabled, first users migrate
**Phase 2 Duration**: 3-6 months (adjust based on service count and complexity)
**Phase 3 Start**: All users migrated, services still in dual-mode
**Phase 3 Duration**: 2-4 weeks (validate all services work with new tokens)
**Phase 4 Start**: Services drop old authorization checks
**Phase 4 Duration**: 1-2 months (services migrate to business role checks only)
**Phase 5 Start**: Remove old groups and service roles from Keycloak

### Grace Period Milestones

**Milestone 1: First Service in Dual-Mode** (Week 1)
- One service updated to accept both old and new authorization
- Test thoroughly in staging
- Deploy to production
- Monitor for issues

**Milestone 2: 50% Services in Dual-Mode** (Month 2)
- Half of services support both models
- No issues reported
- Confidence in dual-mode approach

**Milestone 3: All Services in Dual-Mode** (Month 3)
- All 15+ services accept both old and new authorization
- Begin user migration (Phase 3)
- Token claims include both old and new

**Milestone 4: All Users Migrated** (Month 4-5)
- All users assigned to External/Internal/Services groups
- All users have business roles in Keycloak
- Tokens still include old claims for backward compat

**Milestone 5: Services Drop Old Checks** (Month 6)
- Services remove old `hasRole('service-x-role')` checks
- Only business role checks remain
- Test thoroughly before proceeding

**Milestone 6: Cleanup** (Month 7)
- Remove Group A/B from Keycloak
- Remove service role mappings
- Remove app DB business role tables

### Grace Period Monitoring

**Key Metrics**:
- Token size (ensure not exceeding limits)
- Service error rates (detect authorization failures)
- User migration progress (% of users migrated)
- Service migration progress (% of services in dual-mode)

**Alerting Thresholds**:
- Authorization errors spike: Investigate immediately
- Token size exceeds 6KB: Consider compression or reducing claims
- Service migration stalled: Escalate to team leads

## Rollback Capability

### Why Rollback Is Critical
- Large-scale migration (15+ services)
- Complex authorization logic
- Risk of missed edge cases
- Need confidence to proceed

**Rollback Scenarios**:
1. **Critical bug discovered in dual-mode logic** → Rollback to old model
2. **Token size causes issues** → Rollback to old model
3. **Performance degradation** → Rollback to old model
4. **Compliance issue discovered** → Rollback to old model

### Rollback Design Principles

**Principle 1: Non-Destructive Migration**
- Never delete old groups (Group A/B) until Phase 5
- Never remove old service roles until Phase 5
- Keep app DB business role tables until Phase 5
- Old authorization checks remain until Phase 4

**Principle 2: Feature Flags**
Use feature flags to control migration behavior:

```java
@Service
public class AuthorizationService {

    @Value("${auth.dualMode.enabled:false}")
    private boolean dualModeEnabled;

    @Value("${auth.keycloakBusinessRoles.enabled:false}")
    private boolean keycloakBusinessRolesEnabled;

    public boolean hasAccess(Authentication auth, String resource) {
        if (dualModeEnabled) {
            // Check both old and new authorization
            return hasOldAuthorization(auth, resource) || hasNewAuthorization(auth, resource);
        } else {
            // Check only old authorization (rollback state)
            return hasOldAuthorization(auth, resource);
        }
    }

    public BusinessRole getBusinessRole(Authentication auth) {
        if (keycloakBusinessRolesEnabled) {
            // Try Keycloak first, fall back to DB
            return extractFromToken(auth).orElseGet(() -> findInDatabase(auth));
        } else {
            // Only use database (rollback state)
            return findInDatabase(auth);
        }
    }
}
```

**Principle 3: Service-Level Rollback**
Each service can rollback independently:

```bash
# Rollback service to old authorization only
kubectl set env deployment/order-service AUTH_DUAL_MODE_ENABLED=false

# Rollback all services
kubectl set env deployments --all AUTH_DUAL_MODE_ENABLED=false
```

### Rollback Procedures by Phase

**Phase 2 Rollback (Dual-Mode Deployment)**:
1. Disable dual-mode feature flag on all services
2. Services revert to checking only old service roles
3. No token changes needed (old claims still present)
4. No user data changes needed (Group A/B still assigned)
5. **Time to rollback**: <1 hour (configuration change only)

**Phase 3 Rollback (User Migration)**:
1. Disable dual-mode feature flag on all services
2. Services check only old service roles
3. Users keep new group assignments (harmless, ignored by services)
4. **Optional**: Revert user group assignments (not required)
5. **Time to rollback**: <1 hour (configuration change only)

**Phase 4 Rollback (Service Migration)**:
1. Re-enable old service role checks in services
2. Redeploy services with dual-mode code
3. Validate old authorization works
4. **Time to rollback**: 2-4 hours (code deployment)

**Phase 5 Rollback (Cleanup)**:
1. **CANNOT ROLLBACK** - old groups/roles deleted
2. Must restore from backup or recreate manually
3. **Time to rollback**: Days (data restoration)
4. **Prevention**: Wait 4+ weeks after Phase 4 before Phase 5

### Rollback Testing

**Pre-Migration Rollback Test**:
1. Deploy dual-mode code to staging
2. Enable dual-mode flag
3. Test with old and new tokens
4. Disable dual-mode flag
5. Verify old authorization still works
6. **Success Criteria**: Old model fully functional after flag disable

**Mid-Migration Rollback Test**:
1. Migrate 10% of users in staging
2. Test with mix of old and new tokens
3. Disable dual-mode flag
4. Verify old users still work
5. **Success Criteria**: Old users unaffected by new user migration

## Data Preservation

### Requirement
**No user should lose access at any point during migration.**

### Preservation Strategies

**Strategy 1: Additive Changes Only**
- Add new groups (don't remove old groups)
- Add business roles to Keycloak (don't remove from app DB)
- Add new authorization checks (don't remove old checks)
- **Phase 5 only**: Remove old data (after full validation)

**Strategy 2: Dual Group Membership**
Users belong to BOTH old and new groups:
```
User "alice@example.com"
├─ Group A              // Grants service-role-x, service-role-y, etc.
└─ Internal Users       // Grants Manager business role
```

**Effect**:
- Old services check for Group A: Works
- New services check for Internal Users: Works
- No access lost

**Strategy 3: Dual Business Role Storage**
Business roles exist in BOTH locations:
- App database: `users.business_role = 'Manager'`
- Keycloak token: `realm_access.roles = ['Manager']`

**Effect**:
- Old services query app DB: Works
- New services read token: Works
- No access lost

**Strategy 4: Overlapping Authorization**
During dual-mode, services grant access if EITHER old OR new authorization passes:

```java
@PreAuthorize("hasRole('order-service-role') or hasRole('USER') or hasRole('MANAGER') or hasRole('ADMIN')")
```

**Effect**:
- User with old token (has `order-service-role`): Access granted
- User with new token (has `Manager`): Access granted
- User with transition token (has both): Access granted (redundant but safe)

### Validation Checkpoints

**Before Phase 2 (Dual-Mode Deployment)**:
- [ ] All users have Group A or Group B
- [ ] All users have business role in app DB
- [ ] All services check for service roles
- [ ] Baseline access test: All users can access their services

**After Phase 2 (Dual-Mode Deployment)**:
- [ ] All users still have Group A or Group B
- [ ] Dual-mode services accept old tokens
- [ ] Access test: All users can still access their services
- [ ] Rollback test: Disable dual-mode, verify access still works

**After Phase 3 (User Migration)**:
- [ ] Migrated users have both old and new groups
- [ ] Migrated users have business roles in Keycloak tokens
- [ ] Non-migrated users still have old groups only
- [ ] Access test: Both migrated and non-migrated users can access services

**After Phase 4 (Service Migration)**:
- [ ] All services check business roles (not service roles)
- [ ] All users have business roles in tokens
- [ ] Access test: All users can access services using business role checks
- [ ] Grace period: Wait 2-4 weeks to validate

**Before Phase 5 (Cleanup)**:
- [ ] No authorization errors for 4+ weeks
- [ ] All services confirmed working with business roles only
- [ ] Backup of old groups/roles taken
- [ ] Executive approval to remove old model

## Communication Plan During Transition

### Stakeholder Communication

**Week 0: Migration Kickoff**
- **Audience**: Development teams, product owners, management
- **Message**: Authorization migration starting, dual-mode approach, zero downtime
- **Action**: Provide documentation, training on dual-mode patterns

**Month 1: First Services Migrated**
- **Audience**: Development teams
- **Message**: First services in dual-mode, no issues, pattern validated
- **Action**: Encourage other teams to begin migration

**Month 3: User Migration Begins**
- **Audience**: All stakeholders
- **Message**: User migration starting, no impact to users, rollback available
- **Action**: Monitor support tickets for access issues

**Month 5: Service Migration Complete**
- **Audience**: All stakeholders
- **Message**: All services migrated, grace period starts, monitoring intensified
- **Action**: Report any authorization issues immediately

**Month 7: Cleanup Phase**
- **Audience**: All stakeholders
- **Message**: Old model being removed, new model fully operational
- **Action**: Celebrate successful migration!

### Incident Response During Migration

**Severity 1: Users Losing Access**
- **Response Time**: Immediate (<15 minutes)
- **Action**: Rollback dual-mode flag, restore old authorization
- **Communication**: Notify all stakeholders, post-mortem required

**Severity 2: Authorization Errors in Specific Service**
- **Response Time**: <1 hour
- **Action**: Rollback specific service, investigate root cause
- **Communication**: Notify service team and security team

**Severity 3: Token Size Issues**
- **Response Time**: <4 hours
- **Action**: Enable token compression or reduce claims temporarily
- **Communication**: Notify development teams, adjust migration timeline

## Success Criteria for Backward Compatibility

**Phase 2 Success (Dual-Mode Deployment)**:
- [ ] All services accept both old and new tokens
- [ ] No authorization errors in production
- [ ] Rollback test successful
- [ ] Performance metrics within acceptable range

**Phase 3 Success (User Migration)**:
- [ ] All users migrated to new groups
- [ ] All users have business roles in Keycloak
- [ ] No access lost during migration
- [ ] Old authorization still works (tested)

**Phase 4 Success (Service Migration)**:
- [ ] All services use business role checks only
- [ ] Old service role checks removed
- [ ] All users can access services via business roles
- [ ] Rollback tested and successful

**Phase 5 Success (Cleanup)**:
- [ ] Group A/B removed from Keycloak
- [ ] Service roles removed from Keycloak
- [ ] App DB business role tables removed
- [ ] Token size reduced to target
- [ ] Authorization model fully migrated

## Related Documentation

- [Simple Workflow Overview](./simple-workflow-overview.md) - Target design overview
- [Migration Phases](../04-migration-plan/migration-phases.md) - Detailed migration timeline
- [Rollback Strategy](../04-migration-plan/rollback-strategy.md) - Comprehensive rollback procedures
- [Testing Strategy](../04-migration-plan/testing-strategy.md) - How to test dual-mode compatibility

## Status

**Documented**: 2025-11-20
**Strategy**: Dual-mode with graceful transition
**Estimated Duration**: 6-7 months from Phase 2 to Phase 5
**Risk Level**: Low (with dual-mode and rollback capability)
