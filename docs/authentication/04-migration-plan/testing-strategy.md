# Migration Plan: Testing Strategy

## Summary

This document defines the comprehensive testing strategy for the authorization migration. Testing ensures dual-mode compatibility, validates rollback capability, prevents authorization errors, and maintains security throughout the migration.

**Core Principle**: Test everything before deploying to production. No migration phase proceeds without passing all tests.

## Testing Philosophy

### Test Early, Test Often

**Principle 1: Test in Staging First**
- All migration changes deployed to staging before production
- Full test suite runs in staging
- Production deployment only after staging success

**Principle 2: Automated Testing**
- Authorization test suite runs automatically
- Continuous integration validates every code change
- Automated smoke tests after each deployment

**Principle 3: Test Both Old and New**
- Test with old tokens (Group A/B + service roles)
- Test with new tokens (External/Internal + business roles)
- Test with hybrid tokens (both old and new claims)

**Principle 4: Test Rollback**
- Rollback procedure tested before each phase
- Validate that rollback restores functionality
- Measure rollback time

## Test Environments

### Staging Environment

**Purpose**: Primary testing environment for migration changes

**Configuration**:
- Clone of production Keycloak (anonymized users)
- All 15+ microservices deployed
- Kong gateway configured
- Subset of test users (100-200 users)
- Isolated from production

**Test Data**:
- Test users representing all user types (external, internal, service accounts)
- Test users with all business roles (User, Manager, Admin, Service)
- Test users in old groups (Group A, Group B)
- Test users in new groups (External Users, Internal Users, Services)

### Local Development Environment

**Purpose**: Developer testing during code changes

**Configuration**:
- Keycloak running locally (Docker)
- Single microservice under development
- Mock tokens for testing
- Fast feedback loop

### Production Environment (Canary Testing)

**Purpose**: Final validation with real traffic

**Configuration**:
- Canary deployment: 10% → 50% → 100%
- Real users, real traffic
- Rollback ready
- Monitoring intensified

## Test Types

### Unit Tests

**Purpose**: Test individual authorization methods

**Example: Dual-Mode Authorization Service**
```java
@SpringBootTest
public class AuthorizationServiceTest {

    @Autowired
    private AuthorizationService authorizationService;

    @Test
    public void testOldAuthorization_ServiceRole_ShouldGrantAccess() {
        // Given: User with old service role
        Authentication auth = createOldAuthentication("alice", List.of("order-service-role"));

        // When: Check access
        boolean hasAccess = authorizationService.hasAccess(auth, "order-service");

        // Then: Access granted
        assertTrue(hasAccess);
    }

    @Test
    public void testNewAuthorization_BusinessRole_ShouldGrantAccess() {
        // Given: User with new business role
        Authentication auth = createNewAuthentication("bob", List.of("Manager"));

        // When: Check access
        boolean hasAccess = authorizationService.hasAccess(auth, "order-service");

        // Then: Access granted
        assertTrue(hasAccess);
    }

    @Test
    public void testDualMode_BothAuthorizationMethods_ShouldGrantAccess() {
        // Given: User with both old and new roles
        Authentication auth = createHybridAuthentication(
            "charlie",
            List.of("order-service-role", "User")
        );

        // When: Check access
        boolean hasAccess = authorizationService.hasAccess(auth, "order-service");

        // Then: Access granted (either method works)
        assertTrue(hasAccess);
    }

    @Test
    public void testDualModeDisabled_OnlyOldAuthorization_ShouldWork() {
        // Given: Dual-mode disabled, user with only new role
        authorizationService.setDualModeEnabled(false);
        Authentication auth = createNewAuthentication("dave", List.of("Manager"));

        // When: Check access
        boolean hasAccess = authorizationService.hasAccess(auth, "order-service");

        // Then: Access denied (old authorization required when dual-mode off)
        assertFalse(hasAccess);
    }

    @Test
    public void testBusinessRoleFromToken_ShouldExtractCorrectly() {
        // Given: User with business role in token
        Authentication auth = createNewAuthentication("eve", List.of("Admin"));

        // When: Extract business role
        BusinessRole role = authorizationService.getBusinessRole(auth);

        // Then: Correct role extracted
        assertEquals(BusinessRole.ADMIN, role);
    }

    @Test
    public void testBusinessRoleFromDatabase_Fallback_ShouldWork() {
        // Given: User without business role in token (old user)
        Authentication auth = createOldAuthentication("frank", List.of());
        when(userRepository.findBusinessRoleByUsername("frank"))
            .thenReturn(BusinessRole.USER);

        // When: Get business role
        BusinessRole role = authorizationService.getBusinessRole(auth);

        // Then: Role from database
        assertEquals(BusinessRole.USER, role);
    }
}
```

### Integration Tests

**Purpose**: Test authorization across service boundaries

**Example: End-to-End Order Service Test**
```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
public class OrderServiceIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private TokenGenerator tokenGenerator;

    @Test
    public void testGetOrders_OldToken_ShouldSucceed() throws Exception {
        // Given: Old token with service role
        String token = tokenGenerator.generateOldToken(
            "alice@example.com",
            List.of("Group A"),
            List.of("order-service-role")
        );

        // When: GET /api/orders
        mockMvc.perform(get("/api/orders")
                .header("Authorization", "Bearer " + token))
            // Then: 200 OK
            .andExpect(status().isOk())
            .andExpect(jsonPath("$").isArray());
    }

    @Test
    public void testGetOrders_NewToken_ShouldSucceed() throws Exception {
        // Given: New token with business role
        String token = tokenGenerator.generateNewToken(
            "bob@example.com",
            List.of("Internal Users"),
            List.of("Manager")
        );

        // When: GET /api/orders
        mockMvc.perform(get("/api/orders")
                .header("Authorization", "Bearer " + token))
            // Then: 200 OK
            .andExpect(status().isOk())
            .andExpect(jsonPath("$").isArray());
    }

    @Test
    public void testGetOrders_NoRole_ShouldDeny() throws Exception {
        // Given: Token without appropriate role
        String token = tokenGenerator.generateNewToken(
            "charlie@example.com",
            List.of("External Users"),
            List.of("User")  // External Users should not access orders
        );

        // When: GET /api/orders
        mockMvc.perform(get("/api/orders")
                .header("Authorization", "Bearer " + token))
            // Then: 403 Forbidden
            .andExpect(status().isForbidden());
    }

    @Test
    public void testGetOrders_HybridToken_ShouldSucceed() throws Exception {
        // Given: Hybrid token with both old and new roles
        String token = tokenGenerator.generateHybridToken(
            "dave@example.com",
            List.of("Group A", "Internal Users"),
            List.of("order-service-role", "User")
        );

        // When: GET /api/orders
        mockMvc.perform(get("/api/orders")
                .header("Authorization", "Bearer " + token))
            // Then: 200 OK
            .andExpect(status().isOk());
    }
}
```

### Token Validation Tests

**Purpose**: Verify token structure during migration

**Example: Token Inspector Tests**
```python
import jwt
import requests
import pytest

class TestTokenStructure:

    def test_old_token_structure(self, keycloak_client):
        """Test that old users still get old token structure."""
        # Given: Old user (not migrated)
        token = keycloak_client.get_token(
            username="old.user@example.com",
            password="password"
        )

        # When: Decode token
        decoded = jwt.decode(token, options={"verify_signature": False})

        # Then: Old claims present
        assert "Group A" in decoded["groups"] or "Group B" in decoded["groups"]
        assert "order-service-role" in decoded["realm_access"]["roles"]
        assert "user-service-role" in decoded["realm_access"]["roles"]

        # And: New claims NOT present
        assert "External Users" not in decoded["groups"]
        assert "Internal Users" not in decoded["groups"]
        assert "Manager" not in decoded["realm_access"]["roles"]
        assert "Admin" not in decoded["realm_access"]["roles"]

    def test_new_token_structure(self, keycloak_client):
        """Test that migrated users get hybrid token structure."""
        # Given: Migrated user
        token = keycloak_client.get_token(
            username="migrated.user@example.com",
            password="password"
        )

        # When: Decode token
        decoded = jwt.decode(token, options={"verify_signature": False})

        # Then: Old claims still present (backward compat)
        assert "Group A" in decoded["groups"] or "Group B" in decoded["groups"]

        # And: New claims present
        assert "Internal Users" in decoded["groups"]
        assert "Manager" in decoded["realm_access"]["roles"]

    def test_token_size_within_limits(self, keycloak_client):
        """Test that token size doesn't exceed limits."""
        # Given: Migrated user with hybrid token
        token = keycloak_client.get_token(
            username="migrated.user@example.com",
            password="password"
        )

        # When: Measure token size
        token_size_bytes = len(token.encode('utf-8'))
        token_size_kb = token_size_bytes / 1024

        # Then: Token size within acceptable range
        assert token_size_kb < 8, f"Token size {token_size_kb}KB exceeds 8KB limit"

    def test_business_role_in_token(self, keycloak_client):
        """Test that business roles are included in migrated user tokens."""
        # Given: Migrated user
        token = keycloak_client.get_token(
            username="manager.user@example.com",
            password="password"
        )

        # When: Decode token
        decoded = jwt.decode(token, options={"verify_signature": False})

        # Then: Business role present
        roles = decoded["realm_access"]["roles"]
        assert "Manager" in roles or "Admin" in roles or "User" in roles
```

### Service-to-Service Authorization Tests

**Purpose**: Verify inter-service communication works during migration

**Example: Service Account Tests**
```python
def test_service_to_service_old_token(staging_env):
    """Test service-to-service calls with old service account token."""
    # Given: Service account with old service role
    token = staging_env.keycloak.get_service_token(
        client_id="reporting-service",
        client_secret="secret"
    )

    # When: Reporting service calls Order service
    response = requests.get(
        f"{staging_env.order_service_url}/api/orders/summary",
        headers={"Authorization": f"Bearer {token}"}
    )

    # Then: Call succeeds
    assert response.status_code == 200

def test_service_to_service_new_token(staging_env):
    """Test service-to-service calls with new service token."""
    # Given: Migrated service account with Service role
    service_account = staging_env.keycloak.migrate_service_account(
        client_id="reporting-service"
    )
    token = staging_env.keycloak.get_service_token(
        client_id="reporting-service",
        client_secret="secret"
    )

    # When: Reporting service calls Order service
    response = requests.get(
        f"{staging_env.order_service_url}/api/orders/summary",
        headers={"Authorization": f"Bearer {token}"}
    )

    # Then: Call succeeds
    assert response.status_code == 200
```

### Rollback Tests

**Purpose**: Validate rollback procedures work

**Example: Phase 2 Rollback Test**
```python
def test_phase2_rollback(staging_env):
    """Test Phase 2 rollback: Disable dual-mode, validate old tokens work."""
    # Given: Service in dual-mode
    staging_env.enable_dual_mode("order-service")

    # And: User with old token
    old_token = staging_env.keycloak.get_token(
        username="old.user@example.com",
        password="password"
    )

    # When: Disable dual-mode (rollback)
    staging_env.disable_dual_mode("order-service")

    # Then: Old token still works
    response = requests.get(
        f"{staging_env.order_service_url}/api/orders",
        headers={"Authorization": f"Bearer {old_token}"}
    )
    assert response.status_code == 200

    # And: New token should NOT work (dual-mode off)
    new_token = staging_env.keycloak.get_token(
        username="migrated.user@example.com",
        password="password"
    )
    response = requests.get(
        f"{staging_env.order_service_url}/api/orders",
        headers={"Authorization": f"Bearer {new_token}"}
    )
    # Should fail (no old service role, dual-mode off)
    assert response.status_code == 403
```

### Performance Tests

**Purpose**: Ensure dual-mode doesn't degrade performance

**Example: Latency Test**
```python
import time

def test_dual_mode_latency(staging_env):
    """Test that dual-mode authorization doesn't add significant latency."""
    # Given: Service in dual-mode
    staging_env.enable_dual_mode("order-service")
    token = staging_env.keycloak.get_token(
        username="test.user@example.com",
        password="password"
    )

    # When: Make 100 requests and measure latency
    latencies = []
    for _ in range(100):
        start = time.time()
        response = requests.get(
            f"{staging_env.order_service_url}/api/orders",
            headers={"Authorization": f"Bearer {token}"}
        )
        end = time.time()
        latencies.append(end - start)

    # Then: Average latency within acceptable range
    avg_latency_ms = (sum(latencies) / len(latencies)) * 1000
    assert avg_latency_ms < 200, f"Average latency {avg_latency_ms}ms exceeds 200ms threshold"

    # And: P95 latency within acceptable range
    p95_latency_ms = sorted(latencies)[int(len(latencies) * 0.95)] * 1000
    assert p95_latency_ms < 500, f"P95 latency {p95_latency_ms}ms exceeds 500ms threshold"
```

### Load Tests

**Purpose**: Validate system handles production load during migration

**Example: Load Test with Mixed Token Types**
```python
from locust import HttpUser, task, between

class MigrationLoadTest(HttpUser):
    wait_time = between(1, 3)

    def on_start(self):
        """Get tokens for old and new users."""
        # 50% old users, 50% migrated users
        if random.random() < 0.5:
            self.token = self.get_old_user_token()
            self.user_type = "old"
        else:
            self.token = self.get_migrated_user_token()
            self.user_type = "migrated"

    @task(3)
    def get_orders(self):
        """Simulate user getting their orders."""
        self.client.get(
            "/api/orders",
            headers={"Authorization": f"Bearer {self.token}"}
        )

    @task(1)
    def create_order(self):
        """Simulate user creating an order."""
        self.client.post(
            "/api/orders",
            json={"items": [{"product_id": 123, "quantity": 1}]},
            headers={"Authorization": f"Bearer {self.token}"}
        )

    def get_old_user_token(self):
        """Get token for non-migrated user."""
        response = self.client.post(
            "/auth/realms/james-realm/protocol/openid-connect/token",
            data={
                "grant_type": "password",
                "client_id": "test-client",
                "username": "old.user@example.com",
                "password": "password"
            }
        )
        return response.json()["access_token"]

    def get_migrated_user_token(self):
        """Get token for migrated user."""
        response = self.client.post(
            "/auth/realms/james-realm/protocol/openid-connect/token",
            data={
                "grant_type": "password",
                "client_id": "test-client",
                "username": "migrated.user@example.com",
                "password": "password"
            }
        )
        return response.json()["access_token"]

# Run with: locust -f load_test.py --host=https://staging.example.com --users=100 --spawn-rate=10
```

### Security Tests

**Purpose**: Ensure migration doesn't introduce security vulnerabilities

**Example: Authorization Bypass Test**
```python
def test_cannot_bypass_authorization_with_hybrid_token(staging_env):
    """Test that users cannot gain unauthorized access by manipulating token claims."""
    # Given: User with User role (low privilege)
    token = staging_env.keycloak.get_token(
        username="lowpriv.user@example.com",
        password="password"
    )

    # When: Try to access admin endpoint
    response = requests.get(
        f"{staging_env.admin_service_url}/api/admin/users",
        headers={"Authorization": f"Bearer {token}"}
    )

    # Then: Access denied
    assert response.status_code == 403

def test_external_user_cannot_access_internal_services(staging_env):
    """Test that external users are properly restricted."""
    # Given: External user with User role
    token = staging_env.keycloak.get_token(
        username="external.user@example.com",
        password="password"
    )

    # When: Try to access internal service
    response = requests.get(
        f"{staging_env.reporting_service_url}/api/reports",
        headers={"Authorization": f"Bearer {token}"}
    )

    # Then: Access denied
    assert response.status_code == 403

def test_token_signature_validation(staging_env):
    """Test that services validate token signatures."""
    # Given: Token with invalid signature
    valid_token = staging_env.keycloak.get_token(
        username="test.user@example.com",
        password="password"
    )
    # Tamper with token
    tampered_token = valid_token[:-10] + "XXXXXXXXXX"

    # When: Try to use tampered token
    response = requests.get(
        f"{staging_env.order_service_url}/api/orders",
        headers={"Authorization": f"Bearer {tampered_token}"}
    )

    # Then: Token rejected
    assert response.status_code == 401
```

## Test Scenarios by Phase

### Phase 0: Pre-Migration Preparation

**Test Objectives**:
- Validate test environments are ready
- Baseline performance metrics
- Document current authorization behavior

**Test Checklist**:
- [ ] Staging environment deployed and accessible
- [ ] All 15+ services responding to health checks
- [ ] Test users can authenticate
- [ ] Authorization tests pass with old token structure
- [ ] Performance baseline established (latency, throughput)

**Test Scripts**:
```bash
# Test staging environment
./scripts/test-staging-health.sh

# Run baseline authorization tests
pytest tests/baseline/ --env=staging

# Capture baseline performance
./scripts/performance-baseline.sh > baseline-metrics.json
```

### Phase 1: Keycloak Setup

**Test Objectives**:
- Validate new groups and roles created correctly
- Verify token structure includes new claims
- Ensure old tokens still work (backward compat)

**Test Checklist**:
- [ ] New groups exist in Keycloak (External Users, Internal Users, Services)
- [ ] New roles exist (User, Manager, Admin, Service)
- [ ] Token mappers configured correctly
- [ ] Test user assigned to new group generates token with new claims
- [ ] Test user NOT assigned to new group generates token without new claims (old structure)
- [ ] Token size within acceptable limits

**Test Scripts**:
```bash
# Validate Keycloak configuration
./scripts/validate-keycloak-config.sh

# Test token structure
pytest tests/phase1/test_token_structure.py --env=staging

# Validate backward compatibility
pytest tests/phase1/test_backward_compat.py --env=staging
```

### Phase 2: Dual-Mode Deployment

**Test Objectives**:
- Verify services accept both old and new tokens
- Validate feature flag enables/disables dual-mode
- Ensure no authorization errors for existing users
- Measure performance impact of dual-mode

**Test Checklist**:
- [ ] Service accepts old token (Group A/B + service roles)
- [ ] Service accepts new token (External/Internal + business roles)
- [ ] Service accepts hybrid token (both old and new claims)
- [ ] Feature flag disable → service rejects new tokens (rollback test)
- [ ] Feature flag enable → service accepts both (restore test)
- [ ] Performance impact <20% (latency, throughput)
- [ ] All authorization tests pass

**Test Scripts**:
```bash
# Deploy service to staging with dual-mode
./scripts/deploy-service.sh order-service staging dual-mode

# Test dual-mode authorization
pytest tests/phase2/test_dual_mode.py --service=order-service --env=staging

# Test feature flag rollback
./scripts/test-rollback-phase2.sh order-service

# Performance test
./scripts/performance-test.sh order-service > phase2-perf.json
./scripts/compare-performance.sh baseline-metrics.json phase2-perf.json
```

### Phase 3: User Migration

**Test Objectives**:
- Verify migrated users get tokens with both old and new claims
- Ensure migrated users can access all expected services
- Validate non-migrated users unaffected
- Test user migration rollback

**Test Checklist**:
- [ ] Migrated user token includes old claims (Group A/B, service roles)
- [ ] Migrated user token includes new claims (External/Internal, business roles)
- [ ] Migrated user can access all previously accessible services
- [ ] Migrated user business role matches app DB business role
- [ ] Non-migrated user token unchanged
- [ ] User migration rollback restores old token structure

**Test Scripts**:
```bash
# Migrate test users
./scripts/migrate-users.sh tests/phase3/test_users.csv staging

# Validate migrated user tokens
pytest tests/phase3/test_migrated_users.py --env=staging

# Test service access for migrated users
./scripts/test-user-access.sh migrated.user@example.com staging

# Test rollback
./scripts/rollback-user-migration.sh migrated.user@example.com staging
pytest tests/phase3/test_rollback.py --env=staging
```

### Phase 4: Service Migration

**Test Objectives**:
- Verify services work with new authorization only
- Ensure old authorization checks removed
- Validate all users can still access services
- Test service migration rollback

**Test Checklist**:
- [ ] Service accepts new token (business roles)
- [ ] Service rejects old token without business role (if user not migrated - should not happen by Phase 4)
- [ ] Old authorization code removed from service
- [ ] All authorization tests pass with new tokens
- [ ] Service rollback restores dual-mode functionality

**Test Scripts**:
```bash
# Deploy service with new authorization only
./scripts/deploy-service.sh order-service staging new-auth-only

# Test new authorization
pytest tests/phase4/test_new_auth.py --service=order-service --env=staging

# Validate old code removed
./scripts/validate-code-cleanup.sh order-service

# Test rollback
./scripts/rollback-service-migration.sh order-service staging
pytest tests/phase4/test_rollback.py --service=order-service --env=staging
```

### Phase 5: Cleanup

**Test Objectives**:
- Verify old groups and roles removed
- Ensure tokens only contain new claims
- Validate token size reduced
- Test restoration from backup (rollback simulation)

**Test Checklist**:
- [ ] Old groups (Group A/B) deleted from Keycloak
- [ ] Old service roles deleted from Keycloak
- [ ] Tokens only contain new claims (External/Internal, business roles)
- [ ] Token size reduced by 60-80%
- [ ] All services still work
- [ ] Backup restoration test successful in staging

**Test Scripts**:
```bash
# Cleanup staging environment
./scripts/cleanup-old-auth.sh staging

# Validate token structure
pytest tests/phase5/test_token_cleanup.py --env=staging

# Measure token size reduction
./scripts/measure-token-size.sh > phase5-token-size.json
./scripts/compare-token-size.sh phase3-token-size.json phase5-token-size.json

# Test restoration from backup (disaster recovery simulation)
./scripts/test-backup-restoration.sh staging
```

## Smoke Tests

**Purpose**: Quick validation after each deployment

**Duration**: <5 minutes

**Smoke Test Checklist**:
- [ ] Service health check returns 200
- [ ] User can authenticate with Keycloak
- [ ] User can access protected endpoint with token
- [ ] Authorization error rate <1%
- [ ] Service logs show no critical errors

**Smoke Test Script**:
```bash
#!/bin/bash
# smoke-test.sh - Quick validation after deployment

SERVICE=$1
ENV=$2

echo "Running smoke tests for $SERVICE in $ENV..."

# Health check
echo "1. Health check..."
curl -f https://$ENV.example.com/$SERVICE/health || exit 1

# Authentication test
echo "2. Authentication test..."
TOKEN=$(curl -X POST https://keycloak.$ENV.example.com/auth/realms/james-realm/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=test-client" \
  -d "username=test.user@example.com" \
  -d "password=password" \
  | jq -r '.access_token')

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get token"
  exit 1
fi

# Authorization test
echo "3. Authorization test..."
curl -f -H "Authorization: Bearer $TOKEN" \
  https://$ENV.example.com/$SERVICE/api/health || exit 1

# Check error rate
echo "4. Error rate check..."
ERROR_RATE=$(curl -s "https://prometheus.$ENV.example.com/api/v1/query?query=rate(http_requests_total{service='$SERVICE',status=~'4..|5..'}[5m])" \
  | jq -r '.data.result[0].value[1] // 0')

if (( $(echo "$ERROR_RATE > 0.01" | bc -l) )); then
  echo "ERROR: Error rate $ERROR_RATE exceeds 1%"
  exit 1
fi

echo "✓ Smoke tests passed for $SERVICE"
```

## Automated Test Suites

### Continuous Integration (CI)

**Trigger**: Every code commit

**Tests Run**:
- Unit tests
- Integration tests
- Code coverage check (>80%)
- Security scanning (static analysis)
- Linting and code quality

**CI Pipeline**:
```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Set up JDK 17
        uses: actions/setup-java@v2
        with:
          java-version: '17'

      - name: Run unit tests
        run: ./gradlew test

      - name: Run integration tests
        run: ./gradlew integrationTest

      - name: Check code coverage
        run: ./gradlew jacocoTestReport

      - name: Security scan
        run: ./gradlew dependencyCheckAnalyze

      - name: Upload test results
        uses: actions/upload-artifact@v2
        with:
          name: test-results
          path: build/reports/tests/
```

### Pre-Deployment Tests (Staging)

**Trigger**: Before production deployment

**Tests Run**:
- Full integration test suite
- Authorization tests (old, new, hybrid tokens)
- Performance tests
- Security tests
- Smoke tests

**Duration**: 30-60 minutes

**Deployment Pipeline**:
```yaml
# .github/workflows/deploy-staging.yml
name: Deploy to Staging

on:
  workflow_dispatch:

jobs:
  deploy-and-test:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to staging
        run: ./scripts/deploy-staging.sh ${{ github.sha }}

      - name: Run integration tests
        run: pytest tests/integration/ --env=staging

      - name: Run authorization tests
        run: pytest tests/authorization/ --env=staging

      - name: Run performance tests
        run: ./scripts/performance-test.sh staging

      - name: Run smoke tests
        run: ./scripts/smoke-test-all-services.sh staging

      - name: Publish test report
        uses: actions/upload-artifact@v2
        with:
          name: staging-test-report
          path: test-reports/
```

### Post-Deployment Validation (Production)

**Trigger**: After production deployment

**Tests Run**:
- Smoke tests
- Canary validation
- Real user monitoring

**Duration**: 15-30 minutes

**Validation Steps**:
1. Deploy to 10% of production traffic
2. Run smoke tests
3. Monitor error rates for 15 minutes
4. If successful, increase to 50%
5. Monitor for 15 minutes
6. If successful, deploy to 100%

## Test Data Management

### Test Users

**Old Users (Non-Migrated)**:
```
old.user.1@example.com  | Group A       | No business role in Keycloak
old.user.2@example.com  | Group B       | No business role in Keycloak
external.old@example.com| Group A       | No business role in Keycloak
```

**Migrated Users**:
```
migrated.user@example.com     | Group A + Internal Users | User role
migrated.manager@example.com  | Group A + Internal Users | Manager role
migrated.admin@example.com    | Group A + Internal Users | Admin role
migrated.external@example.com | Group B + External Users | User role
```

**New Users (Phase 5+)**:
```
new.user@example.com     | Internal Users only | User role
new.manager@example.com  | Internal Users only | Manager role
new.admin@example.com    | Internal Users only | Admin role
new.external@example.com | External Users only | User role
```

**Service Accounts**:
```
service-reporting  | Group A + Services | Service role
service-analytics  | Group A + Services | Service role
service-integration| Group B + Services | Service role
```

### Test Data Refresh

**Frequency**: Weekly during migration

**Process**:
1. Export anonymized production data
2. Import to staging
3. Reset test user passwords
4. Validate test suite passes

## Monitoring During Tests

### Key Metrics

**Authorization Metrics**:
- Authorization success rate (target: >99%)
- Authorization error rate (target: <1%)
- Token validation time (target: <10ms)

**Performance Metrics**:
- API latency P50, P95, P99 (target: <200ms, <500ms, <1000ms)
- Throughput (requests per second)
- CPU and memory usage

**Error Metrics**:
- 4xx error rate (client errors)
- 5xx error rate (server errors)
- Failed authentication rate

### Alerting Thresholds

**Critical Alerts** (Page on-call):
- Authorization error rate >5%
- API latency P95 >2000ms
- Service availability <95%

**Warning Alerts** (Slack notification):
- Authorization error rate >1%
- API latency P95 >1000ms
- Token size >6KB

## Test Reporting

### Test Report Template

```markdown
# Authorization Migration Test Report

**Phase**: Phase X - [Phase Name]
**Date**: YYYY-MM-DD
**Environment**: Staging / Production
**Tester**: [Name]

## Summary

- Total tests run: XXX
- Tests passed: XXX (XX%)
- Tests failed: X (X%)
- Tests skipped: X (X%)

## Test Results by Category

### Unit Tests
- Passed: XX/XX
- Failed: X/XX
- Details: [link to report]

### Integration Tests
- Passed: XX/XX
- Failed: X/XX
- Details: [link to report]

### Performance Tests
- Baseline latency: XXXms
- Current latency: XXXms
- Change: +/-XX%
- Details: [link to report]

### Security Tests
- Passed: XX/XX
- Failed: X/XX
- Details: [link to report]

## Issues Found

1. [Issue description]
   - Severity: Critical / High / Medium / Low
   - Status: Open / In Progress / Resolved
   - Assignee: [Name]

## Recommendations

- [Recommendation 1]
- [Recommendation 2]

## Sign-Off

- [ ] All critical tests passed
- [ ] No critical issues found
- [ ] Ready to proceed to next phase / production

**Signed**: [Name]
**Date**: YYYY-MM-DD
```

## Success Criteria for Testing

**Phase 0-1**:
- [ ] 100% of baseline tests passing
- [ ] Test environments validated
- [ ] Test data loaded

**Phase 2**:
- [ ] 100% of dual-mode tests passing
- [ ] Rollback test successful
- [ ] Performance impact <20%

**Phase 3**:
- [ ] 100% of user migration tests passing
- [ ] No migrated users reporting access issues
- [ ] Rollback test successful

**Phase 4**:
- [ ] 100% of new authorization tests passing
- [ ] All services migrated successfully
- [ ] Rollback test successful

**Phase 5**:
- [ ] Token size reduced by 60-80%
- [ ] All tests passing with new tokens only
- [ ] Backup restoration test successful

## Related Documentation

- [Backward Compatibility Strategy](../03-target-design/backward-compatibility.md) - What we're testing
- [Migration Phases](./migration-phases.md) - When to test
- [Rollback Strategy](./rollback-strategy.md) - Rollback testing procedures

## Status

**Documented**: 2025-11-20
**Test Approach**: Comprehensive, automated, phase-by-phase
**Test Coverage Target**: >95% for authorization code
**Test Environment**: Staging (mirrors production)
