locals {
  # Automatically load project-level variables
  project_vars     = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract the variables we need for easy access
  env            = local.environment_vars.locals.environment
  project_id     = local.project_vars.locals.project_id
  project_region = local.project_vars.locals.project_region
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

terraform {
  source = "${path_relative_from_include()}/.././/terraform-modules/gke"
}

inputs = {
  project_id             = local.project_id
  project_region         = local.project_region
  environment            = local.env
}
