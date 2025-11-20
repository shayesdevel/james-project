# Current Authentication Flow (Broken State)

## Overview

This diagram illustrates the current authentication and authorization flow in the james-project system. The flow demonstrates how users are authenticated via Keycloak, assigned to groups, given roles, and how those roles are validated across Kong and the microservices.

## Authentication Flow Diagram

```mermaid
flowchart TD
    Start([User Request])
    Start -->|1. Access App| UI[React UI]

    UI -->|2. Click Login| Redir["Redirect to Keycloak"]

    Redir -->|3. Login Form| KC["Keycloak<br/>(Identity Provider)"]
    KC -->|4. Authenticate Credentials| AuthCheck{Credentials<br/>Valid?}
    AuthCheck -->|No| AuthFail["Authentication Failed"]
    AuthFail --> End1([Return to Login])

    AuthCheck -->|Yes| AssignGroup["Assign User to<br/>Organizational Groups"]
    AssignGroup -->|Groups have no<br/>semantic meaning| GroupDB[(User Group<br/>Membership<br/>DB)]

    KC -->|5. Generate JWT Token<br/>with Groups in Claims| Token["JWT Token<br/>Contains:<br/>- user_id<br/>- username<br/>- groups[]<br/>- scopes[]"]

    Token -->|6. Redirect with Token| UI
    UI -->|7. Store Token<br/>localStorage| UIStore["Token<br/>Storage"]

    UI -->|8. API Request<br/>+ Token Header| Kong["Kong API Gateway<br/>(Routing + Validation)"]

    Kong -->|9. Extract & Validate<br/>Token Signature| KongVal{Token<br/>Valid?}
    KongVal -->|No| KongFail["401 Unauthorized"]
    KongFail --> End2([Request Rejected])

    KongVal -->|Yes| KongRoute["Route Request to<br/>Target Service"]

    Kong -->|10a. Check Token<br/>Scopes & Groups| KongAuthz{User Has<br/>Required<br/>Scopes?}
    KongAuthz -->|No| KongDeny["403 Forbidden"]
    KongDeny --> End3([Request Rejected])

    KongAuthz -->|Yes| Forward["Forward Request to<br/>Service with Token"]

    Forward -->|11. Request arrives<br/>with JWT in header| Service["Spring Boot<br/>Microservice<br/>(Service A, B, C...)"]

    Service -->|12. Extract Roles<br/>from Token Claims| RoleCheck{User Has<br/>Service-Specific<br/>Role?}
    RoleCheck -->|No| ServiceDeny["403 Forbidden"]
    ServiceDeny --> End4([Request Rejected])

    RoleCheck -->|Yes| Execute["Execute Business<br/>Logic"]
    Execute -->|13. Return Response| Response["200 OK<br/>with Data"]

    Response -->|14. Display Result| UIDisplay[React UI<br/>Shows Data]
    UIDisplay --> End5([End])

    style Start fill:#e1f5e1
    style UI fill:#e3f2fd
    style KC fill:#fff3e0
    style Kong fill:#f3e5f5
    style Service fill:#fce4ec
    style Token fill:#ffe0b2
    style End1 fill:#ffebee
    style End2 fill:#ffebee
    style End3 fill:#ffebee
    style End4 fill:#ffebee
    style End5 fill:#e1f5e1
```

## Flow Description

### Phase 1: User Authentication (Steps 1-5)
1. User accesses the React application
2. React UI detects unauthenticated state and redirects to Keycloak login
3. Keycloak presents login form
4. User enters credentials
5. Keycloak validates credentials:
   - On failure: User is returned to login screen
   - On success: User is assigned to organizational groups (with no semantic meaning in the current system)

### Phase 2: Token Generation & Storage (Steps 5-7)
6. Keycloak generates a JWT token containing:
   - User identification (user_id, username)
   - Group memberships (organizational groups)
   - Scopes (broad permission identifiers)
7. Token is sent back to React UI in redirect
8. React stores token in localStorage

### Phase 3: API Request with Token (Steps 8-10)
9. React UI makes API request with token in Authorization header
10. Kong API Gateway receives request and extracts token
11. Kong validates token signature against Keycloak's public key
12. If valid, Kong checks if user's scopes/groups match the required scopes for the endpoint

### Phase 4: Service-Level Authorization (Steps 11-13)
13. Request is forwarded to target Spring Boot microservice with JWT in header
14. Microservice extracts roles from token claims
15. Service checks if user has the specific role for accessing that resource
16. If role present: Access granted (binary yes/no check)
17. If role missing: Request rejected with 403 Forbidden

### Phase 5: Response Handling (Steps 14-15)
18. On success, service returns 200 OK with requested data
19. React UI receives and displays the data to the user

## Key Problems Illustrated

### Problem 1: Meaningless Group Assignment
- Users are assigned to organizational groups that don't map to actual permissions
- These groups must then be mapped to service-level roles
- Creates an extra indirection layer with no security value

### Problem 2: Triple Role Interpretation
Kong validates roles in one way, while each microservice interprets the same role differently:
- Kong checks for ANY matching scope
- Microservices check for presence of SPECIFIC role (binary check)
- No fine-grained authorization logic beyond "role present or not"

### Problem 3: Service-Level Role Explosion
- Each microservice requires its own role (e.g., ROLE_SERVICE_A, ROLE_SERVICE_B)
- A user with 15 microservices gets 15 different roles
- One organizational group assignment → Cascading permissions across all services
- No per-resource or per-action granularity

### Problem 4: No Fine-Grained Control
- Authorization is purely role-based (yes/no)
- No attribute-based control (ABAC)
- No policy-based enforcement
- No per-resource or per-action authorization
- Users with role access can do anything in that service

## Current Limitations

- **No audit trail**: Who accessed what and when is not properly tracked
- **No token revocation**: Tokens cannot be invalidated before expiration
- **No dynamic permissions**: Changing permissions requires role reassignment
- **No delegation**: Users cannot delegate permissions to others
- **No context-aware authorization**: Time, location, or device context not considered

## Security Implications

The current flow results in:
- Users having WAY more permissions than needed (principle of least privilege violated)
- Difficult to audit who has what access
- Difficult to revoke access quickly
- High risk of credential compromise impact
- Compliance violations (GDPR, SOC2, etc.)

