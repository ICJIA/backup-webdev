# Directory Structure Documentation

## Active Structure (Root Level)

The **root-level scripts** are the active, production-ready scripts used by the WebDev Backup Tool. All package.json scripts, the main entry point (`webdev-backup.sh`), and all documentation reference these root-level scripts.

### Key Root-Level Scripts:
- `webdev-backup.sh` - Main launcher (v1.7.0)
- `backup.sh` - Core backup functionality
- `restore.sh` - Restoration utility
- `config.sh` - Configuration management
- `utils.sh`, `fs.sh`, `ui.sh`, `reporting.sh` - Core modules
- `quick-backup.sh` - Quick backup script
- All test scripts (`run-all-tests.sh`, `test-backup.sh`, etc.)

## Alternative Structure (`src/` Directory)

The `src/` directory contains an **alternative organizational structure** that groups scripts into subdirectories:
- `src/core/` - Core configuration and utilities
- `src/utils/` - Utility functions
- `src/ui/` - User interface components
- `src/reports/` - Reporting functions
- `src/security/` - Security-related scripts
- `src/test/` - Test scripts
- `src/setup/` - Setup and configuration scripts

### Current Status

**The `src/` directory is NOT actively used** by the main application. However:
- Test scripts in `src/test/` are referenced by package.json (e.g., `test:cron`, `test:tar`)
- The structure may be useful for future reorganization
- Some scripts may be duplicates or alternative implementations

### Recommendation

1. **For now:** Continue using root-level scripts (current active structure)
2. **Future consideration:** If reorganizing, either:
   - Move all scripts to `src/` structure and update all references
   - Remove `src/` directory if it's not needed
   - Document which scripts in `src/` are actively maintained

### Test Scripts Location

Some test scripts are located in `src/test/`:
- `src/test/test-cron.sh` - Referenced by `npm run test:cron`
- `src/test/test-tar-compatibility.sh` - Referenced by `npm run test:tar`

These are the only scripts from `src/` that are currently referenced by package.json.

---

**Last Updated:** 2025-03-30  
**Version:** 1.7.0

