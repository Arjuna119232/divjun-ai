# HTTP Method Tampering Authentication Bypass Detection

## Description
This skill outlines a methodology to detect authentication bypass vulnerabilities via HTTP method tampering, where standard methods (GET, POST) require authentication but modifying methods (PUT, DELETE, etc.) may bypass authentication checks due to misconfigured routing or authorization logic.

## When to Use
When targeting an API or web endpoint that returns different HTTP status codes or authentication challenges based on the HTTP method used, particularly:
- Standard methods return 401 Unauthorized with WWW-Authenticate header
- Modifying methods return 403 Forbidden without WWW-Authenticate header
- Suggesting the server may skip authentication for certain methods and go straight to authorization checks

## Steps

### 1. Confirm Differential Behavior
   - Request a non-existent endpoint with standard method (GET):
     `curl -s -I https://target.example.com/nonexistent123`
     Expect: 401 + WWW-Authenticate: Basic realm="..."
   - Request same endpoint with modifying method (PUT):
     `curl -s -I -X PUT https://target.example.com/nonexistent123`
     Expect: 403 without WWW-Authenticate header
   - If observed, proceed to step 2.

### 2. Discover Existing Endpoints
   - Use a curated list of common API endpoints (users, admin, data, resource, item, entity, profile, settings, config, v1/users, v1/data, etc.)
   - For each endpoint, test with modifying methods (PUT, DELETE, PATCH) and observe response:
     - 403 Forbidden (without auth challenge) may indicate endpoint exists but method is blocked or requires auth differently
     - 200 OK, 201 Created, 204 No Content, 405 Method Not Allowed, 400 Bad Request (with valid payload) may indicate endpoint processes the method
     - 401 Unauthorized would indicate authentication is still required (not bypassed)
   - Rate limit aggressively: wait 15-30 seconds between requests to avoid triggering WAF/rate limits
   - Use HEAD or OPTIONS to check allowed methods if available (though may also be rate limited)

### 3. Confirm Authentication Bypass
   - For an endpoint that returns non-401/non-403 response to a modifying method without authentication:
     - Test with invalid credentials (e.g., -u "dummy:dummy") to see if response changes
     - If response is identical (e.g., both return 200 OK), authentication may be bypassed
     - If response changes to 401/403 with credentials, authentication is still required
   - Test with valid credentials if available to compare behavior

### 4. Exploit and Impact Analysis
   - If bypass confirmed:
     - Attempt to access sensitive functionality (e.g., PUT /users/1 to update another user's data)
     - Check for IDOR by modifying resource identifiers
     - Attempt to access administrative endpoints (e.g., PUT /admin/config, DELETE /users)
     - Look for excessive data exposure (e.g., GET /users returns list of all users)
     - Attempt to change system state if possible (e.g., updating configurations)

### 5. Document Proof of Concept
   - Clearly show:
     - Request: `PUT /endpoint` without authentication
     - Response: 200 OK (or other success-indicating response) with sensitive data or state change
     - Contrast with: `GET /endpoint` requiring authentication (401)
     - Show impact: e.g., "Updated user #42's email to attacker@evil.com"

## Rate Limiting Evasion
   - Minimum 15-20 seconds between requests to same subdomain
   - Rotate between different in-scope subdomains if rate limit is per subdomain
   - User agent rotation may help but not guaranteed
   - If blocked, wait longer (5-10 minutes) before resuming

## Reporting
   - Clearly state the vulnerability: "Authentication Bypass via HTTP Method Tampering"
   - Provide full request/response logs
   - Demonstrate impact: data access, state change, privilege escalation
   - Note if WAF/rate limiting was encountered and how it was bypassed (if applicable)

## References
   - OWASP Testing Guide: Test for HTTP Methods and XST
   - CWE-284: Improper Access Control
   - CWE-287: Improper Authentication
