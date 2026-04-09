# Maranet Zero — Security Policy

## Reporting a Vulnerability

We take the security of Maranet Zero seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to: **security@maranet.app**

You should receive a response within 48 hours acknowledging your report. For critical vulnerabilities, you may receive a more immediate response.

### What to Include

Please include the following information in your report:

- Type of issue (e.g., buffer overflow, SQL injection, cross-site scripting, etc.)
- Full paths of source file(s) related to the issue
- Location of the affected source code (tag/branch/commit or direct URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

### Preferred Languages

We prefer all communications to be in English.

## Security Measures

### Implemented Security Controls

1. **Authentication & Authorization**
   - JWT-based authentication with refresh tokens
   - Role-based access control (RBAC)
   - Rate limiting on authentication endpoints

2. **Data Protection**
   - TLS/SSL encryption for all external communications
   - Bcrypt password hashing (12 rounds)
   - Input validation with Zod schemas
   - SQL injection protection via Prisma ORM

3. **Network Security**
   - WireGuard VPN for secure tunneling
   - Nginx reverse proxy with security headers
   - Rate limiting at both application and proxy levels
   - IP-based access control for internal services

4. **Infrastructure Security**
   - Non-root Docker containers
   - Systemd service hardening
   - UFW firewall configuration
   - Fail2ban for brute force protection

5. **Dependency Management**
   - Automated Dependabot updates
   - npm audit in CI pipeline
   - Regular security scanning

### Security Headers

All API responses include the following security headers:

- `Strict-Transport-Security`: Enforces HTTPS
- `X-Frame-Options`: Prevents clickjacking
- `X-Content-Type-Options`: Prevents MIME sniffing
- `Content-Security-Policy`: Prevents XSS attacks
- `Referrer-Policy`: Controls referrer information
- `Permissions-Policy`: Controls browser features

## Security Updates

Security updates are released as soon as possible after a vulnerability is confirmed and a fix is available. Updates are announced through:

- GitHub Security Advisories
- Release notes
- Email notifications to registered users (for critical issues)

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Bug Bounty Program

Currently, we do not have a formal bug bounty program. However, we greatly appreciate responsible disclosure and will acknowledge security researchers who help improve our security (unless they prefer to remain anonymous).

## Security Best Practices for Users

When deploying Maranet Zero, please follow these security best practices:

1. **Change all default credentials** before deployment
2. **Use strong, unique secrets** for JWT, database, and Redis
3. **Enable HTTPS** with valid SSL certificates (Let's Encrypt recommended)
4. **Keep the system updated** with the latest security patches
5. **Restrict access** to internal services (Prometheus, Grafana, etc.)
6. **Monitor logs** for suspicious activity
7. **Use a firewall** to limit access to necessary ports only
8. **Regularly rotate secrets** (every 90 days recommended)

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)

---

*This security policy is subject to change. Please check back regularly for updates.*