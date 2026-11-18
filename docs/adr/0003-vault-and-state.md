# ADR 0003 — Vault for the database secret, local state in dev

- Status: accepted
- Date: 2026-11-18

## Context

The ADB ADMIN password must not live in git. Terraform needs it at create time.
The platform also needs a credible answer for secret storage in the architecture.

## Decision

- Keep the password out of `terraform.tfvars`; pass it as
  `TF_VAR_db_admin_password`.
- Write it to an OCI Vault secret encrypted by a Vault master key.
- Use local state for the dev sprint; provide a documented S3-compatible Object
  Storage backend for prod.

## Consequences

Positive:

- The repository contains no database password.
- The Vault path is exercised, including instance-principal read permissions.
- The sprint does not spend time on remote-state bootstrap.

Negative:

- The password is still present in Terraform state and plan files.
- Local state is a single point of loss and is not shared.
- Prod must not ship with local state.

## Follow-up

Before prod:

1. Enable the Object Storage backend with versioning and restricted access.
2. Move state to a dedicated compartment.
3. Consider generating the password in Terraform and rotating it through Vault
   rather than passing it in.
