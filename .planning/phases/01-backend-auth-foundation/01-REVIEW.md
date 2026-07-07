# Phase 1 Review — Backend Authentication Foundation

## Summary
The authentication foundation is functionally in place and verified by integration tests. The main issue uncovered during review is a security problem in configuration handling rather than a runtime logic failure.

### Verification evidence
- Auth integration tests passed with `dotnet test ./tests/SafePath.Api.IntegrationTests/SafePath.Api.IntegrationTests.csproj`
- Result: 2/2 tests passed, 0 failed

## Findings

### 1) Critical — Plaintext database credentials are committed in configuration
- Location: [backend/src/SafePath.Api/appsettings.json](backend/src/SafePath.Api/appsettings.json)
- Evidence: The file contains a Supabase connection string with a username and password embedded directly in the tracked configuration.
- Risk: This exposes production or shared-environment credentials to anyone with repository access and creates a high-severity secret-leak risk.
- Recommendation:
  - Move the connection string to user secrets, environment variables, or a secret store such as Azure Key Vault.
  - Rotate the exposed database password immediately.
  - Remove the secret from git history and ensure it is no longer present in the repo.

### 2) Medium — JWT configuration is configured as a hard startup requirement
- Location: [backend/src/SafePath.Api/Program.cs](backend/src/SafePath.Api/Program.cs)
- Evidence: The app throws immediately if `Jwt:Key`, `Jwt:Issuer`, or `Jwt:Audience` are missing.
- Risk: This is a valid fail-fast approach, but it can make local onboarding and deployment more brittle if configuration is incomplete or mis-ordered.
- Recommendation:
  - Keep the fail-fast behavior for production, but provide clearer startup diagnostics.
  - Consider a development-only fallback for local testing while still warning loudly in non-development environments.

### 3) Low — Authentication coverage is still narrow for edge conditions
- Location: [backend/tests/SafePath.Api.IntegrationTests/AuthEndpointsTests.cs](backend/tests/SafePath.Api.IntegrationTests/AuthEndpointsTests.cs)
- Evidence: The tests cover register/login success and wrong-password rejection, but they do not exercise refresh-token rotation, token reuse detection, or rate-limit behavior.
- Risk: The core happy path is covered, but auth edge cases remain unverified.
- Recommendation:
  - Add tests for refresh-token rotation/reuse scenarios.
  - Add a rate-limit regression test for the login endpoint.

## Recommended next steps
1. Remove the embedded secret from [backend/src/SafePath.Api/appsettings.json](backend/src/SafePath.Api/appsettings.json) and switch to a secret-backed configuration path.
2. Rotate the exposed database credentials.
3. Expand auth tests to cover refresh-token and abuse-protection flows.
