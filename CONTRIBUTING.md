# Contributing to Taproot Assets USD Stablecoin

Thank you for your interest in contributing to the Taproot Assets USD Stablecoin project! This document provides guidelines and information for contributors.

## 🤝 Ways to Contribute

- **Bug Reports**: Report bugs through GitHub Issues
- **Feature Requests**: Suggest new features or improvements
- **Code Contributions**: Submit pull requests with bug fixes or new features
- **Documentation**: Improve documentation and guides
- **Testing**: Add tests or improve test coverage
- **Security**: Report security vulnerabilities responsibly

## 🚀 Getting Started

### Prerequisites

- Ubuntu/Debian Linux environment
- Go 1.21+ installed
- Bitcoin Core
- Basic knowledge of Lightning Network and Bitcoin
- Familiarity with shell scripting

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/yourusername/taproot-assets-stablecoin.git
   cd taproot-assets-stablecoin
   ```

2. **Run Initial Setup**
   ```bash
   ./bin/setup
   ```

3. **Verify Installation**
   ```bash
   ./bin/demo
   ```

## 📋 Development Guidelines

### Code Style

- **Shell Scripts**: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- **Comments**: Use meaningful comments for complex logic
- **Error Handling**: Always check command exit codes
- **Logging**: Use consistent logging format

### Script Structure

```bash
#!/bin/bash

# Script description
# Usage: ./script.sh [options]

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="config.json"

# Functions
main() {
    # Main logic here
}

# Execute main function
main "$@"
```

### Testing

- Test all scripts on clean environment
- Verify Bitcoin/Lightning integration
- Test error scenarios
- Add integration tests for new features

## 🔧 Project Structure

```
taproot-assets-stablecoin/
├── bin/          # Main executables
├── src/          # Source code
├── docs/         # Documentation
├── tests/        # Test suite
├── examples/     # Example code
└── docker/       # Docker configuration
```

## 📝 Pull Request Process

### 1. Branch Naming
- Feature: `feature/description`
- Bug fix: `fix/description`
- Documentation: `docs/description`

### 2. Commit Messages
```
type(scope): description

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit first line to 72 characters
- Reference issues and pull requests liberally
```

### 3. PR Requirements
- [ ] Code follows project style guidelines
- [ ] Self-review of the code
- [ ] Commented complex/hard-to-understand areas
- [ ] Added tests for new functionality
- [ ] All tests pass
- [ ] Documentation updated if needed
- [ ] No merge conflicts

### 4. PR Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tested locally
- [ ] Added/updated tests
- [ ] All tests pass

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-reviewed the code
- [ ] Added comments for complex logic
- [ ] Updated documentation
```

## 🐛 Bug Reports

Include the following information:

### System Information
- OS version
- Bitcoin Core version
- LND version
- Taproot Assets version

### Bug Description
- Expected behavior
- Actual behavior
- Steps to reproduce
- Error messages/logs

### Example
```markdown
**Environment:**
- OS: Ubuntu 22.04
- Bitcoin Core: v25.0.0
- LND: v0.18.4-beta

**Bug:**
Wallet shows incorrect balance after transfer

**Steps:**
1. Send 100 USDT from Alice to Bob
2. Check Alice's balance
3. Balance doesn't update

**Expected:** Balance should decrease by 100
**Actual:** Balance remains unchanged
```

## 🔐 Security

### Reporting Vulnerabilities
- **DO NOT** create public issues for security vulnerabilities
- Email security issues to: [security@yourdomain.com]
- Include detailed description and reproduction steps
- Allow reasonable time for response before public disclosure

### Security Considerations
- Never commit private keys or seeds
- Use secure random number generation
- Validate all inputs
- Follow Bitcoin security best practices

## 📚 Documentation

### Code Documentation
- Document all functions and complex logic
- Include usage examples
- Update README for new features
- Add inline comments for clarity

### API Documentation
- Document all script parameters
- Include return values and error codes
- Provide usage examples
- Update man pages if applicable

## 🧪 Testing

### Unit Tests
```bash
./tests/unit/test-wallet-functions.sh
```

### Integration Tests
```bash
./tests/integration/test-full-workflow.sh
```

### Manual Testing
1. Fresh environment setup
2. Complete workflow testing
3. Error scenario testing
4. Performance testing

## 🏗️ Architecture

### Core Components
- **Bitcoin Core**: Base layer blockchain
- **LND**: Lightning Network implementation
- **Taproot Assets**: Asset protocol layer
- **Wallet Interface**: User interaction layer

### Data Flow
```
User Input → Wallet Interface → Taproot Assets → LND → Bitcoin Core
```

## 📊 Performance

### Optimization Guidelines
- Minimize blockchain queries
- Cache frequently accessed data
- Use efficient data structures
- Profile critical paths

### Benchmarking
```bash
./tests/performance/benchmark-transfers.sh
```

## 🚦 Release Process

### Version Numbering
- Follow [Semantic Versioning](https://semver.org/)
- Format: `MAJOR.MINOR.PATCH`
- Breaking changes increment MAJOR
- New features increment MINOR
- Bug fixes increment PATCH

### Release Checklist
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Changelog updated
- [ ] Version bumped
- [ ] Tagged release created
- [ ] Release notes published

## 🆘 Getting Help

### Community Resources
- **GitHub Issues**: Bug reports and feature requests
- **Discussions**: General questions and ideas
- **Documentation**: Comprehensive guides and API docs

### Development Questions
- Check existing issues and discussions
- Provide minimal reproduction example
- Include relevant system information
- Be patient and respectful

## 📜 License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

## 🙏 Recognition

All contributors will be recognized in:
- README.md contributors section
- Release notes
- Project documentation

Thank you for contributing to the Taproot Assets USD Stablecoin project!