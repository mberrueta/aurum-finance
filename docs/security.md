# Security

Security posture, threat model, controls, and secure development practices.

## Authentication Model

AurumFinance is designed primarily as a **self-hosted, single-operator system**.

The application uses a minimal authentication layer consisting of:

- a single root password
- stored as a bcrypt hash (`AURUM_ROOT_PASSWORD_HASH`)
- session-based authentication using Phoenix signed cookies

This mechanism exists to prevent **unauthorized access from the network**.

### What this protects against

- anonymous access from the internet
- access from other machines on the local network
- accidental exposure of the application endpoint
- opportunistic scanning or indexing

### What this does NOT protect against

This authentication model does **not** protect against operators with host-level access.

Examples:

- a user with root access to the server
- anyone who can read or modify environment variables
- anyone who can modify the Docker configuration or runtime
- anyone with direct access to the database

This limitation is **intentional**.

AurumFinance assumes the operator controls the host environment.

## Design Philosophy

Security mechanisms in AurumFinance prioritize:

- preventing accidental exposure
- protecting network boundaries
- maintaining simplicity appropriate for a self-hosted system

This avoids introducing unnecessary complexity such as:

- multi-user identity systems
- external identity providers
- role-based access control
