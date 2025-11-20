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

## Implementation Details

### Keycloak Configuration Specifics

**Realm Configuration**:
```
Realm Name: james-realm
Login Theme: Default (can customize later)
Token Settings:
  - Access Token Lifespan: 15 minutes
  - SSO Session Idle: 30 minutes
  - SSO Session Max: 10 hours
```

**Group Configuration**:
```json
{
  "groups": [
    {
      "name": "External Users",
      "path": "/External Users",
      "attributes": {
        "description": ["Customers, partners, vendors, external contractors"],
        "type": ["external"]
      }
    },
    {
      "name": "Internal Users",
      "path": "/Internal Users",
      "attributes": {
        "description": ["Employees and internal staff"],
        "type": ["internal"]
      }
    },
    {
      "name": "Services",
      "path": "/Services",
      "attributes": {
        "description": ["Service accounts for machine-to-machine communication"],
        "type": ["service"]
      }
    }
  ]
}
```

**Role Configuration**:
```json
{
  "roles": {
    "realm": [
      {
        "name": "User",
        "description": "Standard user with basic permissions",
        "composite": false
      },
      {
        "name": "Manager",
        "description": "Manager with reporting and team management permissions",
        "composite": false
      },
      {
        "name": "Admin",
        "description": "System administrator with full access",
        "composite": false
      },
      {
        "name": "Service",
        "description": "Service account role for inter-service communication",
        "composite": false
      }
    ]
  }
}
```

**Client Configuration (for microservices)**:
```json
{
  "clientId": "order-service",
  "name": "Order Service",
  "description": "Order management microservice",
  "protocol": "openid-connect",
  "publicClient": false,
  "bearerOnly": true,
  "standardFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": false,
  "attributes": {
    "access.token.lifespan": "900"
  }
}
```

**Token Mapper Configuration**:

Groups Mapper:
```json
{
  "name": "groups",
  "protocol": "openid-connect",
  "protocolMapper": "oidc-group-membership-mapper",
  "config": {
    "full.path": "false",
    "id.token.claim": "true",
    "access.token.claim": "true",
    "claim.name": "groups",
    "userinfo.token.claim": "true"
  }
}
```

Realm Roles Mapper:
```json
{
  "name": "realm roles",
  "protocol": "openid-connect",
  "protocolMapper": "oidc-usermodel-realm-role-mapper",
  "config": {
    "multivalued": "true",
    "userinfo.token.claim": "false",
    "id.token.claim": "true",
    "access.token.claim": "true",
    "claim.name": "realm_access.roles",
    "jsonType.label": "String"
  }
}
```

### Spring Security Integration Points

**Dependencies** (build.gradle):
```gradle
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-security'
    implementation 'org.springframework.boot:spring-boot-starter-oauth2-resource-server'
    implementation 'org.springframework.boot:spring-boot-starter-oauth2-client'

    // For JWT processing
    implementation 'org.springframework.security:spring-security-oauth2-jose'
}
```

**Application Configuration** (application.yml):
```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://keycloak.example.com/auth/realms/james-realm
          jwk-set-uri: https://keycloak.example.com/auth/realms/james-realm/protocol/openid-connect/certs

# Custom authorization configuration
authorization:
  dualMode:
    enabled: false  # Will be true during Phase 2 (Dual-Mode Deployment)
  keycloakBusinessRoles:
    enabled: true   # Read business roles from Keycloak tokens
```

**Security Configuration**:
```java
package com.james.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.web.SecurityFilterChain;

import java.util.*;
import java.util.stream.Collectors;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                // Public endpoints
                .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                // All other endpoints require authentication
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                )
            )
            // Disable CSRF for stateless REST API
            .csrf(csrf -> csrf.disable());

        return http.build();
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(new KeycloakJwtAuthoritiesConverter());
        return converter;
    }

    /**
     * Custom converter to extract roles from Keycloak JWT.
     * Extracts realm_access.roles and prefixes with ROLE_ for Spring Security.
     */
    public static class KeycloakJwtAuthoritiesConverter implements Converter<Jwt, Collection<GrantedAuthority>> {

        @Override
        public Collection<GrantedAuthority> convert(Jwt jwt) {
            Set<GrantedAuthority> authorities = new HashSet<>();

            // Extract realm roles from realm_access.roles
            Map<String, Object> realmAccess = jwt.getClaimAsMap("realm_access");
            if (realmAccess != null && realmAccess.containsKey("roles")) {
                @SuppressWarnings("unchecked")
                List<String> realmRoles = (List<String>) realmAccess.get("roles");
                for (String role : realmRoles) {
                    // Spring Security requires ROLE_ prefix
                    authorities.add(new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()));
                }
            }

            // Extract groups
            List<String> groups = jwt.getClaimAsStringList("groups");
            if (groups != null) {
                for (String group : groups) {
                    // Add groups as authorities for potential group-based checks
                    authorities.add(new SimpleGrantedAuthority("GROUP_" + group.toUpperCase().replace(" ", "_")));
                }
            }

            return authorities;
        }
    }
}
```

**Business Role Enum**:
```java
package com.james.model;

public enum BusinessRole {
    USER("User", 1),
    MANAGER("Manager", 2),
    ADMIN("Admin", 3),
    SERVICE("Service", 4);

    private final String displayName;
    private final int level;

    BusinessRole(String displayName, int level) {
        this.displayName = displayName;
        this.level = level;
    }

    public String getDisplayName() {
        return displayName;
    }

    public int getLevel() {
        return level;
    }

    /**
     * Check if this role has at least the specified minimum level.
     */
    public boolean hasMinimumLevel(BusinessRole minimumRole) {
        return this.level >= minimumRole.level;
    }

    /**
     * Parse from Spring Security authority string (e.g., "ROLE_MANAGER").
     */
    public static BusinessRole fromAuthority(String authority) {
        String roleName = authority.replace("ROLE_", "");
        return BusinessRole.valueOf(roleName.toUpperCase());
    }
}
```

**Authorization Service**:
```java
package com.james.service;

import com.james.model.BusinessRole;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class AuthorizationService {

    /**
     * Get the business role for the authenticated user.
     * Reads from JWT token claim.
     */
    public Optional<BusinessRole> getBusinessRole(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            return Optional.empty();
        }

        // Get authorities from authentication
        List<String> authorities = authentication.getAuthorities().stream()
            .map(GrantedAuthority::getAuthority)
            .filter(auth -> auth.startsWith("ROLE_"))
            .collect(Collectors.toList());

        // Priority: Admin > Manager > User > Service
        if (authorities.contains("ROLE_ADMIN")) {
            return Optional.of(BusinessRole.ADMIN);
        } else if (authorities.contains("ROLE_MANAGER")) {
            return Optional.of(BusinessRole.MANAGER);
        } else if (authorities.contains("ROLE_USER")) {
            return Optional.of(BusinessRole.USER);
        } else if (authorities.contains("ROLE_SERVICE")) {
            return Optional.of(BusinessRole.SERVICE);
        }

        return Optional.empty();
    }

    /**
     * Check if authenticated user has at least the specified minimum role.
     */
    public boolean hasMinimumRole(Authentication authentication, BusinessRole minimumRole) {
        Optional<BusinessRole> userRole = getBusinessRole(authentication);
        return userRole.isPresent() && userRole.get().hasMinimumLevel(minimumRole);
    }

    /**
     * Get the username from JWT token.
     */
    public String getUsername(Authentication authentication) {
        if (authentication instanceof JwtAuthenticationToken) {
            Jwt jwt = ((JwtAuthenticationToken) authentication).getToken();
            return jwt.getClaimAsString("preferred_username");
        }
        return authentication.getName();
    }

    /**
     * Get the user's groups from JWT token.
     */
    public List<String> getGroups(Authentication authentication) {
        if (authentication instanceof JwtAuthenticationToken) {
            Jwt jwt = ((JwtAuthenticationToken) authentication).getToken();
            return jwt.getClaimAsStringList("groups");
        }
        return List.of();
    }

    /**
     * Check if user is in External Users group.
     */
    public boolean isExternalUser(Authentication authentication) {
        return getGroups(authentication).contains("External Users");
    }

    /**
     * Check if user is in Internal Users group.
     */
    public boolean isInternalUser(Authentication authentication) {
        return getGroups(authentication).contains("Internal Users");
    }

    /**
     * Check if user is a service account.
     */
    public boolean isServiceAccount(Authentication authentication) {
        return getGroups(authentication).contains("Services");
    }
}
```

**Controller Examples**:
```java
package com.james.controller;

import com.james.model.BusinessRole;
import com.james.service.AuthorizationService;
import com.james.service.OrderService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @Autowired
    private OrderService orderService;

    @Autowired
    private AuthorizationService authorizationService;

    /**
     * Get user's own orders (any authenticated user).
     * Phase 1: Service-level access control.
     */
    @PreAuthorize("hasRole('USER') or hasRole('MANAGER') or hasRole('ADMIN')")
    @GetMapping("/my-orders")
    public List<Order> getMyOrders(Authentication authentication) {
        String username = authorizationService.getUsername(authentication);
        return orderService.findByUsername(username);
    }

    /**
     * Get all orders (managers and admins only).
     * Phase 1: Service-level access control based on business role.
     */
    @PreAuthorize("hasRole('MANAGER') or hasRole('ADMIN')")
    @GetMapping
    public List<Order> getAllOrders(Authentication authentication) {
        BusinessRole role = authorizationService.getBusinessRole(authentication)
            .orElseThrow(() -> new SecurityException("No business role found"));

        if (role == BusinessRole.MANAGER) {
            // Managers see team orders (business logic determines team)
            return orderService.findByTeam(authentication);
        } else {
            // Admins see all orders
            return orderService.findAll();
        }
    }

    /**
     * Create new order (users, managers, and admins).
     */
    @PreAuthorize("hasRole('USER') or hasRole('MANAGER') or hasRole('ADMIN')")
    @PostMapping
    public Order createOrder(@RequestBody OrderRequest request, Authentication authentication) {
        String username = authorizationService.getUsername(authentication);
        return orderService.createOrder(request, username);
    }

    /**
     * Cancel order (admins only).
     * Phase 1: Service-level access control.
     */
    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/{orderId}")
    public void cancelOrder(@PathVariable Long orderId) {
        orderService.cancelOrder(orderId);
    }

    /**
     * Get order by ID with ownership check.
     * Phase 1: Service-level authorization, business logic enforces ownership.
     */
    @PreAuthorize("hasRole('USER') or hasRole('MANAGER') or hasRole('ADMIN')")
    @GetMapping("/{orderId}")
    public Order getOrderById(@PathVariable Long orderId, Authentication authentication) {
        String username = authorizationService.getUsername(authentication);
        BusinessRole role = authorizationService.getBusinessRole(authentication)
            .orElseThrow(() -> new SecurityException("No business role found"));

        // Business logic: Users can only see their own orders
        // Managers can see team orders, Admins can see all
        return orderService.findById(orderId, username, role);
    }
}
```

### Token Structure Changes (Old vs New)

**Old Token (Current State - Group A/B)**:
```json
{
  "sub": "user-123",
  "preferred_username": "alice@example.com",
  "email": "alice@example.com",
  "groups": ["Group A"],
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

**Token Size**: ~3-4KB (depending on service role count)

**New Token (Target State - External/Internal/Services)**:
```json
{
  "sub": "user-123",
  "preferred_username": "alice@example.com",
  "email": "alice@example.com",
  "groups": ["Internal Users"],
  "realm_access": {
    "roles": ["Manager"]
  }
}
```

**Token Size**: ~1KB (60-75% reduction)

**Transition Token (During Phase 3 - User Migration)**:
```json
{
  "sub": "user-123",
  "preferred_username": "alice@example.com",
  "email": "alice@example.com",
  "groups": [
    "Group A",              // OLD: Kept for backward compatibility
    "Internal Users"        // NEW: Added during migration
  ],
  "realm_access": {
    "roles": [
      "user-service-role",    // OLD: Kept for backward compatibility
      "order-service-role",
      "payment-service-role",
      // ... (other old service roles)
      "Manager"               // NEW: Business role from Keycloak
    ]
  }
}
```

**Token Size**: ~4-5KB (temporary increase during migration)

### How Phase 2 (Controller-Level Granularity) Will Build on Phase 1

**Phase 1 Approach** (Current):
- Service-level access: "Can this user access this service?"
- Binary check: `hasRole('USER')` or `hasRole('MANAGER')`
- Business logic enforces resource ownership and action-level permissions

**Phase 2 Approach** (Future Enhancement):
- Controller-level access: "Can this user perform this specific action on this resource?"
- Permission-based: `hasPermission(#orderId, 'Order', 'READ')`
- Attribute-based access control (ABAC)

**Phase 2 Token Structure** (Future):
```json
{
  "sub": "user-123",
  "preferred_username": "alice@example.com",
  "groups": ["Internal Users"],
  "realm_access": {
    "roles": ["Manager"]
  },
  "permissions": [
    "orders:read:own",      // Read own orders
    "orders:read:team",     // Read team orders
    "orders:write:own",     // Create/update own orders
    "reports:read:all",     // Read all reports
    "users:read:team"       // Read team user data
  ]
}
```

**Phase 2 Permission Evaluator**:
```java
package com.james.security;

import org.springframework.security.access.PermissionEvaluator;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

import java.io.Serializable;

@Component
public class CustomPermissionEvaluator implements PermissionEvaluator {

    @Override
    public boolean hasPermission(Authentication authentication, Object targetDomainObject, Object permission) {
        if (authentication == null || targetDomainObject == null || !(permission instanceof String)) {
            return false;
        }

        String targetType = targetDomainObject.getClass().getSimpleName();
        return hasPermission(authentication, (Serializable) getId(targetDomainObject), targetType, (String) permission);
    }

    @Override
    public boolean hasPermission(Authentication authentication, Serializable targetId, String targetType, Object permission) {
        if (authentication == null || targetType == null || !(permission instanceof String)) {
            return false;
        }

        // Example: Check if user has "orders:read:own" permission
        String permissionString = String.format("%s:%s", targetType.toLowerCase(), permission.toString().toLowerCase());

        // Extract permissions from JWT token
        List<String> userPermissions = extractPermissions(authentication);

        return userPermissions.contains(permissionString);
    }

    private List<String> extractPermissions(Authentication authentication) {
        if (authentication instanceof JwtAuthenticationToken) {
            Jwt jwt = ((JwtAuthenticationToken) authentication).getToken();
            return jwt.getClaimAsStringList("permissions");
        }
        return List.of();
    }

    private Object getId(Object domainObject) {
        // Extract ID from domain object
        // Implementation depends on domain model
        return null;
    }
}
```

**Phase 2 Controller Example**:
```java
/**
 * Phase 2: Fine-grained permission check at controller level.
 */
@PreAuthorize("hasPermission(#orderId, 'Order', 'READ')")
@GetMapping("/{orderId}")
public Order getOrderById(@PathVariable Long orderId) {
    return orderService.findById(orderId);
}

/**
 * Phase 2: Dynamic permission based on action.
 */
@PreAuthorize("hasPermission(#orderId, 'Order', 'UPDATE')")
@PutMapping("/{orderId}")
public Order updateOrder(@PathVariable Long orderId, @RequestBody OrderUpdateRequest request) {
    return orderService.updateOrder(orderId, request);
}
```

**Why Phase 2 is Later**:
- Phase 1 solves the immediate over-permissioning problem (service-level access)
- Phase 1 is simpler to implement and migrate (fewer moving parts)
- Phase 1 establishes the foundation (groups, business roles, token structure)
- Phase 2 builds incrementally on Phase 1 (add permissions without breaking existing roles)
- Don't over-design upfront (validate Phase 1 works before adding complexity)

**Migration from Phase 1 to Phase 2**:
- Phase 1 authorization remains (business role checks)
- Add permission claims to tokens (additive change)
- Add permission evaluator (new component)
- Update controller annotations incrementally (service by service)
- Backward compatible: Old `hasRole` checks continue to work

## Related Documentation

- [Group-Role Mapping](./group-role-mapping.md) - Detailed mapping between groups and roles
- [Backward Compatibility Strategy](./backward-compatibility.md) - How to support both models during migration
- [Current State Overview](../01-current-state/keycloak-overview.md) - What we're replacing
- [Migration Plan](../04-migration-plan/) - How to get from current to target

## Status

**Design Phase**: Initial - Phase 1 (Simple)
**Documented**: 2025-11-20
**Implementation Details Added**: 2025-11-20
**Next Phase**: Phase 2 (Controller-level granularity) - future enhancement
**Implementation Status**: Not yet started
