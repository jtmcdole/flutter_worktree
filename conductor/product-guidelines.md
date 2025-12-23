# Product Guidelines

## Documentation Style
- **Technical and Concise:** Documentation should prioritize clarity and efficiency. Use direct language and avoid unnecessary fluff. Focus on providing high-value information that helps the user accomplish their task as quickly as possible.

## Brand Messaging
- **Simplicity and Ease of Use:** Emphasize the "one-liner" installation and the automated nature of the setup. The user should feel that complex environment management has been made effortless.
- **Efficiency and Productivity:** Highlight the time and disk space saved. Position the tool as an essential utility for professional developers who value a streamlined workflow.

## Development Standards
- **Standardization and Portability:** 
    - **Bash/Zsh:** Scripts must adhere to POSIX standards where possible to ensure compatibility across Linux distributions and macOS.
    - **PowerShell:** Follow standard Windows PowerShell conventions and best practices for naming and error handling.
- **Minimal Dependencies:** Always prefer built-in shell features and standard tools like `git` over third-party dependencies to ensure the scripts run on a "clean" system.

## User Interaction
- **Non-Intrusive and Automated:** Minimize interactive prompts. Design scripts to have sensible defaults and support configuration via environment variables to facilitate unattended installations and CI/CD usage.
- **Fail-Fast:** Scripts should immediately halt and provide a clear error message if a critical dependency or configuration is missing.

## Visual Communication (CLI)
- **Clean and Minimalist:** Use simple status indicators (e.g., emojis like ✅, ❌, ⚠️) to provide quick visual feedback. 
- **Essential Information Only:** Avoid verbose logging by default. Only output what is necessary for the user to understand the current progress or the final outcome.
