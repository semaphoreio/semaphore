# Security Policy

## Reporting a Security Vulnerability

At Semaphore, we take security seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### How to Report

Please send reports about any security related issues you find to:
**support+security@semaphoreci.com**

Please provide as much information as possible, including:

- A detailed description of the vulnerability
- Steps to reproduce the issue
- Potential impact of the vulnerability
- Any possible mitigations you've identified

### Response Process

1. We will acknowledge receipt of your vulnerability report within 3 business day
2. We will provide a more detailed response within 5 business days
   - This will include our assessment of the vulnerability
   - An expected timeline for a fix
3. We will keep you informed about our progress
4. Once the vulnerability is fixed, we will notify you

## Scope

### What to Report

- Vulnerabilities in the open-source Semaphore codebase (outside of `ee/` directory)
- Security issues in our documentation
- Vulnerabilities in our public infrastructure
- Authentication and authorization flaws
- Data exposure risks

### Out of Scope

- Vulnerabilities in Enterprise Edition code (`ee/` directory) - please report through your enterprise support channel
- Social engineering attacks
- DOS/DDOS attempts
- Issues requiring physical access
- Issues in third-party applications or websites

## Security Best Practices

### For Contributors

1. Always follow secure coding guidelines
2. Never commit sensitive information (tokens, passwords, keys)
3. Keep dependencies up to date
4. Write tests for security-critical code
5. Document security-relevant configuration

### For Users

1. Keep your installation up to date
2. Regularly audit access controls
3. Enable all recommended security features
4. Monitor security announcements

## Security Update Process

1. Security patches are given the highest priority
2. Critical vulnerabilities are patched as soon as possible
3. Security updates are clearly marked in release notes
4. When possible, patches are backported to supported versions
5. Users are notified through our security announcement channels

## Public Disclosure Process

- We follow responsible disclosure principles
- Public disclosure is coordinated with the reporter
- Standard disclosure timeline is 90 days
- Timeline may be adjusted based on severity and mitigation complexity

## Security Announcements

Stay informed about security updates:

- Follow our security announcements on [discord](https://discord.com/channels/1097422014735732746/1097434200438755369)
- Follow the announcements on our [website](https://semaphoreci.com/category/semaphore-news)

## Attribution

We believe in acknowledging security researchers who help us improve our security. Unless you prefer to remain anonymous, we will acknowledge your contribution in:

- Our security advisories
- Release notes
