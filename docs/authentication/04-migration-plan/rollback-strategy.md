# Migration Plan: Rollback Strategy

## Summary

This document defines comprehensive rollback procedures for the authorization migration. Each migration phase has specific rollback triggers, procedures, and timelines. The strategy ensures that if anything goes wrong during migration, the system can safely revert to the previous working state with minimal disruption.

**Core Principle**: Non-destructive migration until final cleanup phase. Old authorization model remains functional throughout migration, enabling quick rollback at any phase.

## Rollback Philosophy

### Design for Rollback

**Principle 1: Preserve Old State**
- Don't delete old groups (Group A/B) until Phase 5
- Don't remove old service roles until Phase 5
- Don't drop app DB business role tables until Phase 5
- Keep old authorization code until Phase 4 complete

**Principle 2: Additive Changes**
- Phase 1: Add new groups/roles (don't remove old)
- Phase 2: Add new authorization checks (don't remove old)
- Phase 3: Add new user assignments (don't remove old)
- Phase 4: Only then remove old authorization checks

**Principle 3: Feature Flags**
- Use feature flags to enable/disable new authorization
- Rollback = flip feature flag (no code deployment needed)
- Fast rollback for critical issues

**Principle 4: Validate Before Irreversible Changes**
- Phase 5 is the only irreversible phase
- Wait 4+ weeks after Phase 4 before Phase 5
- Get executive approval before Phase 5
- Take comprehensive backups before Phase 5

## Rollback Triggers

### When to Rollback

**Severity 1: Immediate Rollback Required**
- Multiple users losing access simultaneously
- Authorization errors affecting >10% of requests
- Service outages caused by authorization changes
- Security vulnerability discovered in new authorization
- Data breach or unauthorized access due to migration

**Action**: Immediate rollback, no questions asked

**Severity 2: Planned Rollback Within 1 Hour**
- Authorization errors affecting 5-10% of requests
- Performance degradation >50% due to dual-mode checks
- Token size exceeding limits (>8KB)
- Critical bug discovered in dual-mode logic
- Support ticket volume spike (>5x normal)

**Action**: Investigate quickly, rollback if not resolved in 1 hour

**Severity 3: Planned Rollback Within 24 Hours**
- Authorization errors affecting 1-5% of requests
- Performance degradation 20-50%
- Edge cases discovered affecting small user segment
- Migration falling behind schedule significantly
- Team confidence loss in new authorization

**Action**: Investigate, attempt fix, rollback if unresolved in 24 hours

**Severity 4: No Rollback, Fix Forward**
- Authorization errors affecting <1% of requests
- Minor performance impact (<20%)
- Isolated edge cases with workarounds
- Cosmetic issues or logging problems

**Action**: Fix in place, no rollback needed

### Rollback Decision Authority

**Phase 0-3 (Low Risk)**:
- Tech lead can authorize rollback
- Notify product owner and stakeholders
- Post-mortem within 24 hours

**Phase 4 (Medium Risk)**:
- Product owner approval required
- Security team notification
- Post-mortem within 48 hours

**Phase 5 (High Risk - Irreversible)**:
- Executive approval required for starting Phase 5
- Cannot rollback once complete (restoration only)
- Incident response team on standby

## Phase-by-Phase Rollback Procedures

## Phase 0: Pre-Migration Preparation

### Rollback Trigger
**N/A** - Phase 0 is read-only (no production changes)

### Rollback Procedure
**N/A** - No rollback needed

### Data Loss
**None** - No changes made to production

---

## Phase 1: Keycloak Setup

### Rollback Triggers
- New groups or roles breaking token generation
- Token size exceeding limits
- Keycloak configuration errors
- Token mapper misconfiguration

### Rollback Procedure

**Step 1: Remove Token Mappers**
```bash
# Use Keycloak Admin API or UI
DELETE /auth/admin/realms/james-realm/protocol-mappers/groups-mapper
DELETE /auth/admin/realms/james-realm/protocol-mappers/realm-roles-mapper
```

**Step 2: Remove Business Roles**
```bash
# Use Keycloak Admin API or UI
DELETE /auth/admin/realms/james-realm/roles/User
DELETE /auth/admin/realms/james-realm/roles/Manager
DELETE /auth/admin/realms/james-realm/roles/Admin
DELETE /auth/admin/realms/james-realm/roles/Service
```

**Step 3: Remove New Groups**
```bash
# Use Keycloak Admin API or UI
DELETE /auth/admin/realms/james-realm/groups/external-users
DELETE /auth/admin/realms/james-realm/groups/internal-users
DELETE /auth/admin/realms/james-realm/groups/services
```

**Step 4: Validate Rollback**
- [ ] Generate token for test user
- [ ] Verify token contains only old claims (Group A/B, service roles)
- [ ] Verify token does not contain new claims
- [ ] Test token against staging services

### Rollback Time
**<1 hour** - Configuration changes only

### Data Loss
**None** - No users assigned to new groups yet

### Rollback Validation
```bash
# Test token structure
curl -X POST https://keycloak.example.com/auth/realms/james-realm/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=test-client" \
  -d "username=test.user@example.com" \
  -d "password=testpassword" \
  | jq '.access_token' | jwt decode -

# Expected: Token has only old groups and service roles
# Should NOT have: External/Internal/Services groups, User/Manager/Admin roles
```

---

## Phase 2: Dual-Mode Deployment

### Rollback Triggers
- Authorization errors spike in migrated services
- Performance degradation due to dual checks
- Dual-mode logic bug discovered
- Service deployment failures

### Rollback Procedure

**Option A: Feature Flag Rollback (Preferred)**

**Step 1: Disable Dual-Mode Feature Flag**
```bash
# For all services using ConfigMap
kubectl patch configmap authorization-config -n production \
  --type merge \
  -p '{"data":{"authorization.dualMode.enabled":"false"}}'

# Restart pods to pick up new config
kubectl rollout restart deployment -n production
```

**Step 2: Validate Rollback**
- [ ] Services check only old service roles
- [ ] New business role checks disabled
- [ ] Authorization errors return to baseline

**Rollback Time**: <30 minutes (config change + pod restart)

**Option B: Service Redeployment (If Feature Flag Fails)**

**Step 1: Redeploy Old Service Versions**
```bash
# Rollback to previous deployment
kubectl rollout undo deployment/order-service -n production
kubectl rollout undo deployment/user-service -n production
# ... for all migrated services
```

**Step 2: Validate Rollback**
- [ ] Services running previous version (before dual-mode)
- [ ] Authorization works as before migration

**Rollback Time**: 1-2 hours (service redeployments)

### Per-Service Rollback

If only one service has issues:

```bash
# Rollback specific service
kubectl set env deployment/order-service -n production \
  AUTHORIZATION_DUAL_MODE_ENABLED=false

# Or redeploy previous version
kubectl rollout undo deployment/order-service -n production
```

**Rollback Time**: <10 minutes per service

### Data Loss
**None** - No user data changes in Phase 2

### Rollback Validation
```bash
# Test authorization with old token
curl -H "Authorization: Bearer $OLD_TOKEN" \
  https://api.example.com/orders/health

# Expected: 200 OK

# Test that new role checks are disabled
kubectl logs deployment/order-service -n production | grep "dual-mode"
# Expected: "dual-mode: disabled" or no dual-mode logs
```

---

## Phase 3: User Migration

### Rollback Triggers
- Users losing access after migration
- Wrong groups or roles assigned
- Token generation failures
- Mass authorization errors

### Rollback Procedure

**Option A: Feature Flag Rollback + Keep User Assignments (Preferred)**

**Step 1: Disable Dual-Mode (Services Check Only Old Authorization)**
```bash
# Disable dual-mode across all services
kubectl patch configmap authorization-config -n production \
  --type merge \
  -p '{"data":{"authorization.dualMode.enabled":"false"}}'

kubectl rollout restart deployment -n production
```

**Step 2: Validate Users Can Access Services**
- [ ] Migrated users can still access services (via old groups/roles)
- [ ] Non-migrated users unaffected
- [ ] Authorization errors return to baseline

**Result**: Services ignore new groups/roles, check only old groups/roles. Users keep new assignments (harmless).

**Rollback Time**: <30 minutes

**Option B: Revert User Assignments (If Feature Flag Rollback Insufficient)**

**Step 1: Remove New Group Assignments**
```python
# revert_user_migration.py
from keycloak import KeycloakAdmin

keycloak_admin = KeycloakAdmin(
    server_url="https://keycloak.example.com/auth/",
    username="admin",
    password="admin_password",
    realm_name="james-realm"
)

def revert_user(username, new_group, business_role):
    """Revert user migration by removing new group and role."""
    try:
        user = keycloak_admin.get_user_id(username)

        # Remove from new group
        keycloak_admin.group_user_remove(user, new_group)

        # Remove business role
        role = keycloak_admin.get_realm_role(business_role)
        keycloak_admin.delete_realm_roles_of_user(user, [role])

        print(f"✓ Reverted {username}")
        return True
    except Exception as e:
        print(f"✗ Failed to revert {username}: {str(e)}")
        return False

# Revert all migrated users
with open('migrated_users.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        revert_user(
            username=row['username'],
            new_group=row['target_group'],
            business_role=row['target_keycloak_role']
        )
```

**Step 2: Validate Tokens Revert to Old Structure**
- [ ] Generate token for reverted user
- [ ] Verify token contains only old groups/roles
- [ ] Verify token does not contain new groups/roles

**Rollback Time**: 1-2 hours (depends on user count)

### Per-User Rollback

If only specific users have issues:

```python
# Revert single user
revert_user(
    username="alice@example.com",
    new_group="Internal Users",
    business_role="Manager"
)
```

**Rollback Time**: <5 minutes per user

### Data Loss
**None** - Old groups/roles preserved throughout Phase 3

### Rollback Validation
```bash
# Test user access after rollback
curl -X POST https://keycloak.example.com/auth/realms/james-realm/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=production-client" \
  -d "username=alice@example.com" \
  -d "password=password" \
  | jq '.access_token' | jwt decode -

# Expected: Token has only old groups (Group A/B) and service roles
# Should NOT have: External/Internal/Services or User/Manager/Admin in active claims

# Test service access
curl -H "Authorization: Bearer $TOKEN" \
  https://api.example.com/orders/

# Expected: 200 OK
```

---

## Phase 4: Service Migration

### Rollback Triggers
- Services denying access after removing old checks
- Edge case users without business roles
- Hidden dependencies on old authorization
- Authorization errors spike

### Rollback Procedure

**Option A: Redeploy Dual-Mode Code (Preferred)**

**Step 1: Redeploy Previous Version (Dual-Mode)**
```bash
# For each migrated service, rollback to dual-mode version
kubectl rollout undo deployment/order-service -n production
kubectl rollout undo deployment/user-service -n production
# ... for all migrated services
```

**Step 2: Enable Dual-Mode Feature Flag**
```bash
kubectl patch configmap authorization-config -n production \
  --type merge \
  -p '{"data":{"authorization.dualMode.enabled":"true"}}'

kubectl rollout restart deployment -n production
```

**Step 3: Validate Services Accept Both Old and New Authorization**
- [ ] Test with old token (Group A/B + service roles)
- [ ] Test with new token (External/Internal + business roles)
- [ ] Both should work

**Rollback Time**: 2-4 hours (code deployment)

**Option B: Emergency Hotfix (If Deployment Fails)**

**Step 1: Add Old Authorization Checks Back**
```java
// Emergency hotfix: Add old service role check back
@PreAuthorize("hasRole('order-service-role') or hasRole('USER') or hasRole('MANAGER') or hasRole('ADMIN')")
@GetMapping("/api/orders")
public List<Order> getOrders() {
    return orderService.findOrders();
}
```

**Step 2: Build and Deploy Hotfix**
```bash
# Build hotfix
./gradlew build -x test  # Skip tests for speed

# Deploy hotfix
kubectl set image deployment/order-service \
  order-service=registry.example.com/order-service:hotfix-rollback -n production
```

**Rollback Time**: 1-2 hours (hotfix development + deployment)

### Per-Service Rollback

If only one service has issues:

```bash
# Rollback specific service to dual-mode
kubectl rollout undo deployment/order-service -n production

# Or deploy hotfix for specific service
kubectl set image deployment/order-service \
  order-service=registry.example.com/order-service:v1.2.3-dual-mode -n production
```

**Rollback Time**: 30 minutes per service

### Data Loss
**None** - Tokens still contain both old and new claims (if Phase 5 not started)

**IMPORTANT**: If Phase 5 has started (old groups/roles removed from Keycloak), rollback becomes HARD. Must restore Keycloak from backup.

### Rollback Validation
```bash
# Test with old token (should work after rollback)
curl -H "Authorization: Bearer $OLD_TOKEN" \
  https://api.example.com/orders/

# Expected: 200 OK

# Test with new token (should still work)
curl -H "Authorization: Bearer $NEW_TOKEN" \
  https://api.example.com/orders/

# Expected: 200 OK

# Check logs for dual-mode
kubectl logs deployment/order-service -n production | grep "authorization"
# Expected: Both old and new authorization checks present
```

---

## Phase 5: Cleanup

### Rollback Triggers
**CRITICAL**: Phase 5 is irreversible. Rollback requires restoration from backup.

**Phase 5 Should Only Start If**:
- All services stable for 4+ weeks after Phase 4
- Zero authorization errors in production
- Executive approval obtained
- Comprehensive backups taken

### Rollback Procedure (Restoration)

**WARNING**: This is not a true rollback. It is a disaster recovery restoration that takes days.

**Step 1: Restore Keycloak from Backup**
```bash
# Stop Keycloak
kubectl scale deployment/keycloak --replicas=0 -n keycloak

# Restore Keycloak database from backup
pg_restore -h keycloak-db.example.com -U keycloak -d keycloak \
  keycloak_backup_pre_phase5.dump

# Restart Keycloak
kubectl scale deployment/keycloak --replicas=3 -n keycloak
```

**Step 2: Restore Application Databases from Backup**
```bash
# For each microservice with business role tables
pg_restore -h user-service-db.example.com -U userservice -d userservicedb \
  user_service_backup_pre_phase5.dump

pg_restore -h order-service-db.example.com -U orderservice -d orderservicedb \
  order_service_backup_pre_phase5.dump

# ... for all service databases
```

**Step 3: Redeploy Services with Dual-Mode Code**
```bash
# Deploy dual-mode versions of all services
kubectl apply -f k8s/deployments/dual-mode/ -n production

# Enable dual-mode
kubectl patch configmap authorization-config -n production \
  --type merge \
  -p '{"data":{"authorization.dualMode.enabled":"true"}}'

kubectl rollout restart deployment -n production
```

**Step 4: Validate Restoration**
- [ ] Old groups (Group A/B) exist in Keycloak
- [ ] Old service roles exist in Keycloak
- [ ] Business role tables exist in app databases
- [ ] Services check both old and new authorization
- [ ] Users can authenticate and access services

**Restoration Time**: 1-3 days (complex, multi-step process)

### Data Loss
**Potential Data Loss**:
- Any Keycloak changes made after backup (user creation, role changes, etc.)
- Any app DB changes made after backup (depends on backup strategy)
- User tokens in-flight (users must re-authenticate)

**Mitigation**:
- Take backups immediately before Phase 5
- Minimize time between backup and Phase 5 start
- Communicate to users about potential re-authentication

### Rollback Validation
```bash
# Validate Keycloak restoration
curl https://keycloak.example.com/auth/admin/realms/james-realm/groups | jq '.[] | .name'
# Expected: Group A, Group B, External Users, Internal Users, Services

curl https://keycloak.example.com/auth/admin/realms/james-realm/roles | jq '.[] | .name'
# Expected: user-service-role, order-service-role, ..., User, Manager, Admin, Service

# Validate app DB restoration
psql -h user-service-db.example.com -U userservice -d userservicedb \
  -c "SELECT * FROM users LIMIT 1;"
# Expected: business_role column exists

# Test user access
curl -X POST https://keycloak.example.com/auth/realms/james-realm/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=production-client" \
  -d "username=alice@example.com" \
  -d "password=password" \
  | jq '.access_token' | jwt decode -

# Expected: Token has both old and new claims

curl -H "Authorization: Bearer $TOKEN" https://api.example.com/orders/
# Expected: 200 OK
```

---

## Backup Strategy

### Pre-Migration Backups

**Before Phase 1** (Baseline):
- [ ] Keycloak database full backup
- [ ] All app database full backups
- [ ] Keycloak realm configuration export
- [ ] Service deployment configurations

**Before Phase 2** (Before Code Changes):
- [ ] Keycloak database full backup
- [ ] Service deployment configurations
- [ ] Git tags for all service repositories

**Before Phase 3** (Before User Migration):
- [ ] Keycloak database full backup (users about to change)
- [ ] Export user-to-group-to-role mappings

**Before Phase 4** (Before Service Migration):
- [ ] Keycloak database full backup
- [ ] App database full backups
- [ ] Service deployment configurations

**Before Phase 5** (CRITICAL - Last Chance):
- [ ] Keycloak database FULL backup
- [ ] All app database FULL backups
- [ ] Keycloak realm configuration export
- [ ] User-to-group-to-role mapping export
- [ ] Service deployment configurations
- [ ] Validation that backups are restorable (test restore in staging)

### Backup Retention

**Phase 0-4 Backups**:
- Retain for 90 days
- Can be deleted after Phase 5 successfully completes

**Phase 5 Pre-Cleanup Backup**:
- Retain for 1 year
- Critical for disaster recovery

### Backup Validation

**Before Starting Each Phase**:
```bash
# Validate Keycloak backup
pg_restore --list keycloak_backup.dump | head -20
# Expected: List of database objects

# Test restore in staging
pg_restore -h keycloak-staging-db.example.com -U keycloak -d keycloak_test \
  keycloak_backup.dump

# Validate restored data
psql -h keycloak-staging-db.example.com -U keycloak -d keycloak_test \
  -c "SELECT count(*) FROM user_entity;"
# Expected: User count matches production
```

## Incident Response Playbook

### Incident: Mass Authorization Failures

**Symptoms**:
- 10%+ of requests return 403 Forbidden
- User reports flooding support
- Multiple services affected

**Immediate Actions**:
1. Identify affected phase (check recent deployments)
2. Execute appropriate phase rollback procedure
3. Notify stakeholders via Slack/email
4. Monitor error rates during rollback
5. Validate rollback success

**Timeline**:
- Decision to rollback: <15 minutes
- Rollback execution: 30 minutes to 2 hours (depends on phase)
- Validation: 15-30 minutes
- **Total**: <3 hours from incident to resolution

**Post-Incident**:
- Post-mortem within 24 hours
- Root cause analysis
- Fix identified issues
- Re-plan migration phase

### Incident: Single Service Authorization Failures

**Symptoms**:
- One service returning 403 errors
- Other services working fine
- Error isolated to specific service

**Immediate Actions**:
1. Rollback specific service (not entire environment)
2. Validate other services unaffected
3. Investigate service-specific issue
4. Fix and redeploy

**Timeline**:
- Decision to rollback: <15 minutes
- Service rollback: 10-30 minutes
- Validation: 10 minutes
- **Total**: <1 hour

### Incident: User Assigned Wrong Role

**Symptoms**:
- User reporting incorrect permissions
- Single user or small group affected
- User has too much or too little access

**Immediate Actions**:
1. Verify user's current groups and roles in Keycloak
2. Update user's role assignment to correct value
3. Ask user to re-authenticate (new token with correct role)
4. Validate user now has correct access

**Timeline**:
- Investigation: 10 minutes
- Role correction: 5 minutes
- Validation: 5 minutes
- **Total**: <30 minutes

**No Rollback Needed** - Fix in place

### Incident: Token Size Exceeds Limits

**Symptoms**:
- Tokens rejected by Kong gateway (header too large)
- 400 Bad Request errors
- Tokens cannot be stored in browser (localStorage limit)

**Immediate Actions**:
1. Measure current token size
2. Enable token compression in Keycloak (if available)
3. Remove unnecessary claims temporarily
4. If still exceeding limits, rollback to previous phase

**Timeline**:
- Investigation: 15 minutes
- Compression/optimization: 30 minutes
- If rollback needed: 1-2 hours
- **Total**: 2 hours max

## Rollback Testing

### Pre-Migration Rollback Tests

**Before Starting Migration**:

**Test 1: Phase 1 Rollback Simulation**
1. Create new groups/roles in staging
2. Generate test tokens
3. Delete groups/roles
4. Validate tokens revert to old structure

**Test 2: Phase 2 Rollback Simulation**
1. Deploy dual-mode services to staging
2. Enable dual-mode feature flag
3. Test with both old and new tokens
4. Disable feature flag
5. Validate old tokens still work

**Test 3: Phase 3 Rollback Simulation**
1. Migrate test users in staging
2. Validate new tokens work
3. Revert user assignments
4. Validate old tokens still work

**Test 4: Phase 4 Rollback Simulation**
1. Deploy new authorization code to staging
2. Test with new tokens
3. Redeploy dual-mode code
4. Validate both old and new tokens work

**Test 5: Phase 5 Restoration Simulation**
1. Take backup of staging Keycloak
2. Delete old groups/roles
3. Restore from backup
4. Validate old groups/roles exist
5. Test user access

### Rollback Drills

**Monthly Rollback Drill During Migration**:
- Practice rollback procedure for current phase
- Measure rollback time
- Identify any issues with rollback process
- Update rollback documentation

## Communication Plan During Rollback

### Severity 1 Incident (Immediate Rollback)

**T+0 minutes (Incident Detected)**:
- Post to #incident-response Slack channel
- Page on-call engineer
- Start incident bridge

**T+15 minutes (Rollback Decision Made)**:
- Email stakeholders: "Authorization migration rollback in progress"
- Update status page: "Investigating authorization issues"

**T+30-120 minutes (Rollback In Progress)**:
- Regular updates every 15 minutes on Slack
- Update status page with progress

**T+XXX minutes (Rollback Complete)**:
- Email stakeholders: "Rollback complete, services restored"
- Update status page: "Issue resolved"
- Schedule post-mortem

**T+24 hours (Post-Mortem)**:
- Post-mortem document published
- Stakeholder meeting to discuss next steps

### Severity 2-3 Incident (Planned Rollback)

**T+0 (Investigation Starts)**:
- Post to #authorization-migration Slack channel
- Notify tech lead and product owner

**T+1-24 hours (Rollback Decision Made)**:
- Email stakeholders: "Authorization migration rollback planned"
- Schedule rollback during maintenance window (if possible)

**T+X (Rollback Executed)**:
- Post-mortem within 48 hours
- Plan for next migration attempt

## Success Criteria for Rollback Capability

**Phase 0-1 Success**:
- [ ] Rollback tested in staging
- [ ] Rollback time <1 hour
- [ ] Backups validated

**Phase 2 Success**:
- [ ] Feature flag rollback tested
- [ ] Per-service rollback tested
- [ ] Rollback time <30 minutes

**Phase 3 Success**:
- [ ] User assignment revert tested
- [ ] Feature flag rollback tested
- [ ] Rollback time <1 hour

**Phase 4 Success**:
- [ ] Service redeployment rollback tested
- [ ] Dual-mode restoration validated
- [ ] Rollback time <2 hours

**Phase 5 Success**:
- [ ] Full restoration tested in staging
- [ ] Backup restoration validated
- [ ] Restoration procedure documented
- [ ] Team trained on restoration (even though we hope to never use it)

## Rollback Decision Matrix

| Phase | Issue Severity | Affected Users | Error Rate | Decision | Timeline |
|-------|----------------|----------------|------------|----------|----------|
| Any | Sev1 | >10% | >10% | Immediate Rollback | <15 min |
| Any | Sev2 | 5-10% | 5-10% | Rollback in 1 hour | <1 hour |
| 0-3 | Sev3 | <5% | 1-5% | Rollback in 24 hours | <24 hours |
| 4-5 | Sev3 | <5% | 1-5% | Fix Forward | N/A |
| Any | Sev4 | <1% | <1% | Fix Forward | N/A |

## Related Documentation

- [Backward Compatibility Strategy](../03-target-design/backward-compatibility.md) - Dual-mode design
- [Migration Phases](./migration-phases.md) - Full migration timeline
- [Testing Strategy](./testing-strategy.md) - How to test rollback procedures

## Status

**Documented**: 2025-11-20
**Rollback Philosophy**: Non-destructive until Phase 5
**Max Rollback Time**: <3 hours (Phases 0-4), 1-3 days (Phase 5 restoration)
**Testing Status**: Rollback drills required before each phase
