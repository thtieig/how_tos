# Git Repository Sanitisation Tool

A Bash script to sanitise Git repositories by replacing author and committer email addresses with a consistent replacement identity. This tool is useful for cleaning up commit history when migrating repositories or consolidating author identities.

## Features

- **Batch Processing**: Process multiple repositories from a list
- **Email Replacement**: Replace specified emails with a consistent replacement identity
- **Verification**: Built-in verification to ensure complete sanitisation
- **Safe Operation**: Interactive confirmation before force-pushing
- **Auto-approve Mode**: Automated processing with `AUTO_APPROVE=1`
- **Comprehensive Logging**: Detailed logging of all operations
- **Git-filter-repo Integration**: Uses the powerful `git-filter-repo` tool for efficient history rewriting

## Prerequisites

- `git` - Version control system
- `git-filter-repo` - Advanced git history filtering tool

Install `git-filter-repo` with one of the following methods:

**Using pip (recommended for latest version):**
```bash
pip3 install git-filter-repo
```

**Using apt (Ubuntu/Debian):**
```bash
sudo apt update && sudo apt install git-filter-repo
```

## Setup

1. Clone or download this repository
2. Create the required input files (see Configuration section)
3. Make the script executable:
   ```bash
   chmod +x sanitise_repos.sh
   ```

## Configuration

### Optional Configuration File

The script can be configured using an optional `config.sh` file in the same directory as the script. Copy `config.sh.example` to `config.sh` and modify the values as needed.

If no `config.sh` file is present, the script will use default values and prompt for confirmation before pushing repositories.

### Required Files

The script requires two input files in the same directory as the script:

#### `repos.txt`
List of Git repository URLs to process, one per line (HTTPS or SSH):
```
https://github.com/yourusername/repo1.git
https://github.com/yourusername/repo2.git
https://github.com/yourusername/repo3.git
```

**Quick setup for GitHub users**: If you have the [GitHub CLI](https://cli.github.com/) installed and authenticated, you can automatically generate this file for all your repositories:

```bash
gh repo list YOUR_GITHUB_USERNAME --limit 1000 --json sshUrl -q '.[].sshUrl' > repos.txt
```

This will fetch all your repositories and save their SSH URLs to `repos.txt`. Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username.

#### `emails.txt`
List of email addresses to replace, one per line:
```
oldemail1@example.com
oldemail2@example.com
oldemail3@example.com
```

**Note**: Example configuration files (`repos.txt` and `emails.txt`) are provided in this repository. Replace the example content with your actual repository URLs and email addresses.

### Configuration Variables

Configure these variables if needed:

**Option 1: Using config.sh (Recommended):**
```bash
cp config.sh.example config.sh
# Edit config.sh with your preferred values
```

**Option 2: Using environment variables:**
```bash
REPLACEMENT_NAME="Your Name" REPLACEMENT_EMAIL="your.email@example.com" ./sanitise_repos.sh
```

**Option 3: Edit directly in the script:**
Modify the variables at the top of `sanitise_repos.sh` (not recommended for regular use).

- `REPLACEMENT_NAME`: Name for the replacement identity (default: "Noname")
- `REPLACEMENT_EMAIL`: Email for the replacement identity (default: "dev@users.noreply.github.com")
- `REPOS_FILE`: Path to repositories file (default: "repos.txt")
- `EMAILS_FILE`: Path to emails file (default: "emails.txt")
- `WORK_DIR`: Working directory for processing (default: "sanitise_workdir")
- `LOG_FILE`: Log file path (default: "sanitisation_log.txt")
- `AUTO_APPROVE`: Set to 1 to automatically push without confirmation (default: 0)

## Usage

### Interactive Mode (Safe)

Run the script normally for interactive processing:
```bash
./sanitise_repos.sh
```

The script will:
1. Check prerequisites and required files
2. Display the replacement identity and emails to sanitise
3. Process each repository:
   - Clone the repository
   - Check for presence of target emails
   - Show before/after samples of commits
   - Request confirmation before force-pushing
4. Log all operations to `sanitisation_log.txt`

### Auto-approve Mode

For automated processing without confirmations:
```bash
AUTO_APPROVE=1 ./sanitise_repos.sh
```

⚠️ **Warning**: This will force-push all repositories without confirmation. Use with extreme caution!

## What It Does

1. **Cloning**: Downloads each repository to a temporary work directory
2. **Analysis**: Searches for commits containing the specified emails
3. **Mailmap Creation**: Creates a `.mailmap` file to map old emails to replacement identity
4. **History Rewriting**: Uses `git-filter-repo` to rewrite commit history
5. **Verification**: Confirms all target emails have been replaced
6. **Publishing**: Force-pushes the sanitised repository (with confirmation)

## Output Files

- **`sanitisation_log.txt`**: Detailed log of all operations
- **`sanitise_workdir/`**: Temporary working directory (created during processing)

## Safety Features

- **Verification Step**: Ensures sanitisation was successful before pushing
- **Interactive Confirmation**: Requires user approval before force-pushing
- **Skip Unchanged Repos**: Skips repositories that don't contain target emails
- **Comprehensive Logging**: All operations are logged for audit purposes

## Important Notes

- ⚠️ **Force Push**: This script performs force pushes, which will overwrite remote history
- 🔄 **Backups**: Ensure you have backups of repositories before running this script
- ⏰ **Time-consuming**: Large repositories with extensive history may take significant time
- 🌐 **Network**: Requires internet access for cloning and pushing repositories

## Troubleshooting

### Common Issues

- **"git-filter-repo is required but not installed"**
  ```bash
  pip3 install git-filter-repo
  ```

- **"repos.txt not found" or "emails.txt not found"**
  - Ensure these files exist and contain the required data

- **"Verification FAILED"**
  - The sanitisation may have missed some emails
  - Check the log file for details
  - This prevents unsafe force-pushing

- **Permission denied when pushing**
  - Ensure you have write access to the repositories
  - Check your Git authentication/credentials

### Logging

All operations are logged to `sanitisation_log.txt`. Check this file for:
- Detailed error messages
- Processing status for each repository
- Verification results
- Push outcomes

## License

This project is provided as-is for educational and maintenance purposes. Use at your own risk.
