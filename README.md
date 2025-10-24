# Git Repository Tools & How-Tos

A collection of Git repository management tools and step-by-step guides for various repository operations and maintenance tasks.

## Available Tools & Guides

### 🔧 [commit_sanitiser](./commit_sanitiser/)
**Git Repository Sanitisation Tool**

A Bash script to sanitise Git repositories by replacing author and committer email addresses with a consistent replacement identity. This tool is useful for:
- Cleaning up commit history when migrating repositories
- Consolidating author identities across multiple emails
- Preparing repositories for open source or organizational standards

[View README](./commit_sanitiser/README.md) | [Usage Guide](./commit_sanitiser/README.md#usage)

### 🛡️ [repo_sanitiser](./repo_sanitiser/)
**Rewrite Repository History Guide**

A detailed step-by-step guide for rewriting Git repository history to remove leaked secrets (API tokens, passwords, keys) and other sensitive information that was accidentally committed.

Key features:
- Complete secret removal from Git history
- Step-by-step security incident response
- Prevention strategies for future incidents
- Both manual and automated approaches

[View Guide](./repo_sanitiser/Rewrite_Repo_History.md)

---

## 📄 License

See individual tool/guide directories for license information.
