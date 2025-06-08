# Entra Management Console - Deployment Guide

## State Migration Guide

### Current to Modular Structure Migration

1. **Create New Workspace**
   ```bash
   # In Terraform Cloud:
   1. Create new workspace: "entra-management-prod-modular"
   2. Set working directory to: environments/prod
   3. Configure variables from old workspace
   ```

2. **State Migration Steps**
   ```bash
   # 1. Pull current state
   terraform state pull > old-state.json

   # 2. Create new state file structure
   terraform state push -force old-state.json

   # 3. Verify resources
   terraform state list
   ```

3. **Resource Mapping**
   - Map old resource names to new modular structure
   - Update any cross-references
   - Verify managed identities and access policies

4. **Migration Validation**
   - Run terraform plan to verify no unexpected changes
   - Check resource dependencies
   - Verify access policies and permissions

5. **Switch Workspaces**
   - Update CI/CD pipelines to use new workspace
   - Update documentation
   - Archive old workspace

### Post-Migration Verification
1. Verify all resources are accessible
2. Check application functionality
3. Validate monitoring and logging
4. Test security configurations
5. Verify cost management settings
