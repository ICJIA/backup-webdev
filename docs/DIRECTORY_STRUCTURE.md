# Directory Structure Documentation

**Last Updated:** 2025-03-30  
**Version:** 1.7.0  
**Status:** Consolidated - src/ archived

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

## Archived Structure (`archive/src.legacy/`)

The `src/` directory has been **archived** to `archive/src.legacy/` as of version 1.7.0. This directory contained an alternative organizational structure that grouped scripts into subdirectories:
- `archive/src.legacy/core/` - Core configuration and utilities (archived)
- `archive/src.legacy/utils/` - Utility functions (archived)
- `archive/src.legacy/ui/` - User interface components (archived)
- `archive/src.legacy/reports/` - Reporting functions (archived)
- `archive/src.legacy/security/` - Security-related scripts (archived)
- `archive/src.legacy/test/` - Test scripts (archived, but still referenced)
- `archive/src.legacy/setup/` - Setup and configuration scripts (archived)

### Current Status

**The `archive/src.legacy/` directory is archived and NOT actively used** by the main application. However:
- Test scripts in `archive/src.legacy/test/` are still referenced by package.json (e.g., `test:cron`, `test:tar`)
- These test scripts have been updated to correctly source root-level modules
- The archived structure is preserved for reference but should not be modified

### Test Scripts Location

Test scripts are located in `archive/src.legacy/test/`:
- `archive/src.legacy/test/test-cron.sh` - Referenced by `npm run test:cron`
- `archive/src.legacy/test/test-tar-compatibility.sh` - Referenced by `npm run test:tar`

These scripts have been updated to source modules from the root directory using `ROOT_DIR` variable.

### Why Archive Instead of Delete?

The `src/` structure was archived rather than deleted to:
1. Preserve alternative organizational approach for future reference
2. Maintain test scripts that are still in use
3. Allow for potential future reorganization if needed
4. Keep history of project structure evolution

### Recommendation

1. **Current approach:** Use root-level scripts (active structure)
2. **Test scripts:** Continue using archived test scripts (they work correctly)
3. **Future:** If reorganizing, consider moving all scripts to a structured `src/` directory, but update all references comprehensively

---

**Note:** Do not modify files in `archive/src.legacy/` unless you're updating test script source paths or moving them to root level.
