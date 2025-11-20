# Broken Authorization: The Over-Permissioning Catastrophe

## Executive Summary

The current Keycloak authorization model grants authenticated users access to far too many services and resources, creating a catastrophic security vulnerability. This document explains why the current state is broken, the security implications, and provides concrete examples of the problem.

**Severity**: CRITICAL
**Impact**: 15+ microservices exposed to all authenticated users
**Root Cause**: Automatic group assignment granting meaningless roles

## The Problem in Plain English

**What Should Happen**:
Users should only have access to the specific services and resources they need to do their job.

**What Actually Happens**:
Every authenticated user receives roles for most or all microservices, making authentication the only real security boundary.

**Why This Is Catastrophic**:
"Are you logged in?" becomes the only meaningful security check, not "What are you allowed to do?"

## Root Cause Analysis

### The Broken Chain

```
1. User is created in Keycloak
      ↓
2. User is auto-assigned to meaningless groups
      ↓
3. Groups grant roles for each microservice (15+ roles)
      ↓
4. ALL roles appear in user's JWT token
      ↓
5. Spring Security checks: "Does token have role X?"
      ↓
6. Answer is always YES for most users
      ↓
7. Authorization = Authentication (BROKEN)
```

### Why Groups Are Meaningless

**The Actual Groups**: New users are assigned to **Group A** OR **Group B**

**The Problem**:
- "Group A" and "Group B" are arbitrary labels with no business meaning
- Assignment logic between A vs. B is unclear
- No connection to actual job functions, departments, or responsibilities
- Names provide zero context about what users in these groups should be able to do

**What Makes This Especially Broken**:
Business roles (User, Manager, Admin) **exist in the application database**, NOT in Keycloak:
- Spring Security checks these business roles via custom logic in the application
- Keycloak groups (Group A, Group B) have NO RELATIONSHIP to business roles
- There's a complete disconnect between:
  - **Keycloak groups** (Group A, Group B) → Grant service-level access
  - **Business roles** (User, Manager, Admin) → Checked by application code
- No way to know a user's business role from their Keycloak token
- Authorization decisions split between Keycloak and application database

**What Groups SHOULD Represent** (but don't):
- User categories (External Users, Internal Users, Service Accounts)
- Job functions that map to business roles
- Clear permission boundaries

### Why Roles Are Over-Granted

**The Pattern**:
Group A and Group B both grant **dozens of service roles** with slight overlap.

**Example** (15+ microservices):
```
User "alice@example.com" is created
  ↓
Auto-assigned to Group A
  ↓
Group A grants dozens of service roles:
  - user-service-role
  - order-service-role
  - payment-service-role
  - inventory-service-role
  - shipping-service-role
  - analytics-service-role
  - reporting-service-role
  - admin-service-role
  - billing-service-role
  - customer-service-role
  - notification-service-role
  - audit-service-role
  - integration-service-role
  - export-service-role
  - import-service-role
  - ... (and many more)
```

**Result**:
- Alice has access to dozens of services, regardless of her actual job or needs
- The "slight overlap" between Group A and Group B creates confusion about what each group provides
- No meaningful difference in permission levels between the two groups
- Standard users get way too much permission to services they shouldn't use

## Security Implications

### 1. Violation of Least Privilege

**Principle**: Users should have minimum access required to perform their job.
**Reality**: Users have maximum access by default.

**Impact**:
- Support staff can access payment processing
- Read-only users can trigger writes
- External contractors can access internal tools
- Customers can access administrative functions (if they get authenticated)

### 2. No Defense in Depth

**Principle**: Multiple layers of security controls should protect resources.
**Reality**: Authentication is the only layer; authorization is bypassed.

**Impact**:
- Compromised credentials = full system access
- No containment of insider threats
- No segmentation between service tiers
- Single point of failure (credential theft)

### 3. Compliance Nightmares

**Requirements** (SOC2, GDPR, HIPAA, etc.):
- Audit who can access what
- Demonstrate least privilege
- Prove access is role-appropriate
- Show access reviews and certifications

**Reality**:
- Cannot prove who should have access (everyone has everything)
- Access reviews are meaningless (everyone shows all permissions)
- Audit trails show access but cannot show violations (nothing is violating since all access is granted)
- Cannot demonstrate compliance with access controls

### 4. Blast Radius of Security Incidents

**Scenario**: Attacker compromises single user account

**With Proper Authorization**:
- Attacker gains access to user's specific permissions
- Limited to user's department or role
- Can be contained to specific services
- Lateral movement requires additional privilege escalation

**With Current System**:
- Attacker gains access to 15+ microservices immediately
- Can access data across all business domains
- Can perform actions in any service
- No additional escalation needed (already at maximum privilege)

### 5. Insider Threat Amplification

**Malicious Insider Scenario**:
- Disgruntled employee with legitimate credentials
- Decides to exfiltrate data or sabotage systems

**With Proper Authorization**:
- Limited to services relevant to their job
- Access is logged and can be revoked by department
- Damage is contained to their domain

**With Current System**:
- Access to all services across organization
- Can exfiltrate data from unrelated departments
- Can cause damage in services they never legitimately needed
- Harder to detect (all access appears "authorized")

## Concrete Examples

### Example 1: Customer Support Representative

**What They Need**:
- Read access to customer records
- Read access to order history
- Ability to create support tickets

**What They Get** (current system):
- Access to payment processing service
- Access to inventory management
- Access to analytics and reporting
- Access to admin functions
- Access to billing service
- Access to shipping configuration

**Security Risk**:
- Can view payment details they don't need
- Can modify inventory (fraud opportunity)
- Can access reports containing sensitive data
- Can perform administrative actions

### Example 2: Marketing Analyst

**What They Need**:
- Read access to analytics service
- Read access to reporting service
- Export capability for their reports

**What They Get** (current system):
- Access to customer personal data (all services)
- Access to order processing
- Access to payment systems
- Access to shipping and fulfillment
- Access to user management

**Security Risk**:
- GDPR violation (access to unnecessary personal data)
- Can view financial transactions
- Can access operational systems
- No business justification for most access

### Example 3: External Integration Partner

**What They Need**:
- Webhook endpoint to receive events
- Read access to specific integration APIs

**What They Get** (current system):
- Full access to 15+ microservices
- Ability to read all data types
- Ability to invoke any service endpoint (if role check is binary)

**Security Risk**:
- Third party has excessive access to internal systems
- No boundary between external and internal services
- Compliance violation (sharing access with external party)
- Difficult to audit and revoke

## Why Spring Security Checks Fail

### The Binary Role Check Problem

**Current Pattern** (assumed in each microservice):
```java
@PreAuthorize("hasRole('order-service-role')")
@GetMapping("/api/orders/{id}")
public Order getOrder(@PathVariable Long id) {
    return orderService.findById(id);
}
```

**What This Checks**:
- "Does the user's token contain 'order-service-role'?"
- Answer: YES (always, for every user)

**What This DOESN'T Check**:
- Is this user a customer viewing their own order?
- Is this user a support rep with permission to help this customer?
- Is this user an admin with order management permissions?
- Does this user have any business reason to access this specific order?

**Result**: Authorization degrades to authentication.

### No Resource-Level Authorization

**Missing Capabilities**:
- Cannot check if user can access specific order ID
- Cannot differentiate read vs. write vs. delete
- Cannot enforce ownership (user can only see their own data)
- Cannot implement approval workflows
- Cannot restrict based on data attributes (region, department, sensitivity)

**Example Impact**:
```java
// User A can see User B's orders
// Customer can see admin orders
// Everyone can see everyone's data (if they know the ID)
GET /api/orders/12345  // Returns order regardless of who is asking
```

## Cascade Effect Across Microservices

### Problem Multiplication

With 15+ microservices:
- 15+ binary role checks that all pass
- 15+ services with no real authorization boundary
- 15+ potential data leakage points
- 15+ compliance gaps

### Service Interdependencies

**Scenario**: Microservices call each other
```
User Request → Service A → Service B → Service C
```

**Current State**:
- User token has roles for all three services
- Each service checks role: passes
- No additional authorization at service boundaries
- Internal service calls inherit full user permissions

**Risk**:
- User doesn't need direct access to Service C
- But can access it through Service A's API
- Or can directly call Service C (since they have the role)
- No way to distinguish direct vs. delegated access

## Attempted Workarounds (And Why They Fail)

### Workaround 1: Add More Groups

**Idea**: Create fine-grained groups for different user types
**Why It Fails**:
- Groups are still auto-assigned (who decides which groups?)
- Still results in too many roles per user
- Doesn't solve resource-level authorization
- Maintenance nightmare (group explosion)

### Workaround 2: Custom Authorization Code in Services

**Idea**: Add manual permission checks in service code
**Why It Fails**:
- Bypasses Keycloak entirely (why use it then?)
- Inconsistent implementation across 15+ services
- No centralized policy management
- Difficult to audit
- Every service reinvents the wheel

### Workaround 3: Remove Roles from Services

**Idea**: Just don't check roles at all
**Why It Fails**:
- Even worse security posture
- Unauthenticated access would be required
- No benefit from Keycloak integration

### Workaround 4: Manual Group Assignment

**Idea**: Remove auto-assignment, manually assign groups
**Why It Fails**:
- Doesn't scale to many users
- Still group-based (wrong abstraction)
- Doesn't address resource-level or action-level authorization
- Administrative burden on identity team

## Why This Is Called "Catastrophic"

### Quantifying the Impact

**Unauthorized Access Surface**:
- Users: Assume 100 users
- Services: 15 microservices
- Endpoints: Assume 20 endpoints per service = 300 total endpoints
- Over-permission: Assume each user should only access 2 services (13 service over-grant)

**Math**:
- Each user has access to 13 services they shouldn't
- 13 services × 20 endpoints = 260 unauthorized endpoints per user
- 100 users × 260 endpoints = 26,000 unauthorized access paths

**Reality Check**: That's 26,000 opportunities for data breach, fraud, or abuse.

### Audit Discovery Scenario

**What Auditor Asks**:
"Show me who has access to payment processing."

**Honest Answer**:
"Everyone who can authenticate."

**Auditor Response**:
"That's a critical finding. Show me remediation plan."

### Breach Scenario

**Incident**: Single user credential compromised (phishing, stolen password)

**Damage Potential**:
- Access to all 15 microservices
- Ability to read sensitive data across domains
- Ability to perform actions in any service
- Difficult to detect (all access appears legitimate)
- Difficult to contain (must revoke all access, not just specific services)

**Breach Notification**:
- Must assume all data across all services was potentially accessed
- Regulatory notification requirements triggered (GDPR, state laws)
- Customer trust damage
- Financial and reputational cost

## The Business Impact

### Development Velocity

**Current State**:
- Developers assume all users have all permissions
- No need to think about authorization design
- Security is someone else's problem

**Long-Term Impact**:
- Security debt accumulates
- Impossible to add proper authorization later without rewriting
- Cannot safely add new services (they inherit the same broken model)
- Cannot onboard external partners or customers safely

### Operational Risk

**Production Incidents**:
- User performs action in wrong service (had access, shouldn't have)
- Data corruption from unauthorized modifications
- Cannot roll back access (everyone has everything)

**Example**: Marketing analyst accidentally triggers order cancellation in production because they had access to order-service and clicked the wrong button in a UI.

## Path Forward (Preview)

This document describes the CURRENT BROKEN STATE. The path forward involves:

1. **Proper Role Design**: Roles represent actual job functions, not services
2. **Resource-Based Authorization**: Check ownership and permissions on specific resources
3. **Attribute-Based Policies**: Consider user attributes, resource attributes, and context
4. **Least Privilege**: Grant minimum necessary access
5. **Separation of Concerns**: Service roles vs. business roles vs. permissions

See future documentation in `02-target-design/` for proposed solution.

## Summary

**The Core Problem**: Authorization is broken because authentication and authorization have been conflated.

**Root Cause**: Automatic group assignment granting meaningless roles for all microservices.

**Impact**: Every authenticated user has excessive access to most or all services.

**Severity**: Catastrophic - violates security principles, compliance requirements, and creates massive attack surface.

**Next Steps**: Document target design with proper authorization model.

## Related Documentation

- [Keycloak Overview](./keycloak-overview.md) - Current configuration details
- [Group-Based Issues](./group-based-issues.md) - Technical breakdown of failures
- [README](../README.md) - Documentation navigation

## Status

**Documented**: 2025-11-20
**Severity Assessment**: CRITICAL
**Business Risk**: HIGH
**Compliance Risk**: HIGH
**Remediation Priority**: IMMEDIATE
