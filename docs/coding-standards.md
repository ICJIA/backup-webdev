# WebDev Backup Tool - Coding Standards

This document outlines the coding standards and best practices for the WebDev Backup Tool project.

## Shell Script Style Guide

### File Structure

1. **File Header**: Each script should begin with:

   ```bash
   #!/bin/bash
   # filename.sh - Brief description of purpose
   # Detailed description including usage information
   ```

2. **Section Organization**: Use comment blocks to separate sections:

   ```bash
   # ===================================
   # CONFIGURATION
   # ===================================
   ```

3. **Import Order**: Source files in the following order:
   - Configuration files
   - Utility functions
   - UI functions
   - Domain-specific modules

### Naming Conventions

1. **Variables**:

   - Use `UPPER_CASE` for constants and environment variables
   - Use `lower_case` for local variables
   - Prefix private/internal functions and variables with underscore `_`

2. **Functions**:
   - Use `snake_case` for function names
   - Add descriptive comments before each function explaining:
     - Purpose
     - Parameters
     - Return values or exit codes

### Code Style

1. **Indentation**: Use 4 spaces for indentation (not tabs)

2. **Line Length**: Keep lines under 80 characters when possible

3. **Quoting**:

   - Always quote variables: `"$variable"` not `$variable`
   - Use double quotes for strings with variables
   - Use single quotes for literal strings

4. **Error Handling**:

   - Always check return values of commands
   - Use the central `handle_error` function for error reporting
   - Set appropriate exit codes for different error conditions

5. **Command Substitution**:

   - Use `$()` instead of backticks: `$(command)` not `` `command` ``

6. **Conditional Checks**:
   - Use `[[` for conditional expressions (not `[` or `test`)
   - Use `&&` and `||` for simple conditionals, `if/then` for multi-line

### Security Best Practices

1. **Input Validation**:

   - Always validate and sanitize user input
   - Use parameter validation functions when accepting arguments

2. **Command Execution**:

   - Avoid using `eval` whenever possible
   - Use arrays for command construction to prevent injection

3. **File Operations**:

   - Check file existence before operations
   - Validate file permissions before reading/writing
   - Use secure temporary files with proper cleanup

4. **Credentials**:
   - Never hardcode credentials in scripts
   - Use the secrets.sh file with proper permissions (600)
   - Document credential requirements clearly

### Documentation

1. **Function Documentation**: Document all functions using this format:

   ```bash
   # @function       function_name
   # @description    What the function does
   # @param {type}   param_name - Parameter description
   # @returns        Return value description or exit codes
   function_name() {
       # Implementation
   }
   ```

2. **Script Usage**: Include usage examples in comments at the top of each script

## Testing Requirements

1. All scripts must have corresponding tests
2. Tests should verify:
   - Normal operation paths
   - Error handling paths
   - Edge cases (empty input, very large input, etc.)

## Version Control Practices

1. Use descriptive commit messages
2. Mention ticket/issue numbers in commits when applicable
3. Don't commit:
   - Credentials or secrets
   - Large binary files
   - Temporary files or build artifacts

## Error Codes Reference

| Code | Meaning                  | Action                                   |
| ---- | ------------------------ | ---------------------------------------- |
| 1    | Configuration error      | Check configuration files and paths      |
| 2    | File system error        | Check permissions and disk space         |
| 3    | Missing dependencies     | Install required software packages       |
| 4    | Permission denied        | Fix permissions or run with sudo         |
| 5    | Network error            | Check connection and firewall settings   |
| 6    | Backup creation failed   | Check logs for specific error details    |
| 7    | Verification failed      | Validate backup integrity and retry      |
| 8    | Restore operation failed | Check source backup and destination      |
| 9    | Cloud operation failed   | Check credentials and network connection |
| 10   | Invalid arguments        | Check command syntax                     |
| 99   | Unknown error            | Check detailed logs                      |

## Multi-Directory Backup Architecture

The WebDev Backup Tool supports backing up multiple source directories. This functionality is implemented using the following design:

1. **Configuration**:

   - `DEFAULT_SOURCE_DIRS` array in `config.sh` stores the list of directories to back up
   - Default directory is `~` (home directory) to back up all folders

2. **Command Line Options**:

   - Single directory: `--source /path/to/dir`
   - Multiple directories: `--sources /path/to/dir1,/path/to/dir2,/path/to/dir3`

3. **Project Discovery**:

   - The tool scans each source directory independently
   - Projects are tracked with their full paths to prevent name collisions

4. **Backup Organization**:

   - Projects are backed up with their source directory name as prefix
   - Format: `source_dirname_project_name_timestamp.tar.gz`
   - This ensures projects with the same name from different sources don't conflict

5. **Restoration**:
   - The restore tool is aware of multi-directory backups
   - Users can choose to restore to original location or custom destination

### Adding New Source Directories

To add new source directories for monitoring, you can:

1. Specify them at runtime using the `--source` or `--sources` options
2. Edit `config.sh` and add entries to the `DEFAULT_SOURCE_DIRS` array
3. Use the interactive launcher and select "Add Source Directory" from the menu

For directories with custom requirements, create directory-specific exclude files in the
`.config` subdirectory.
