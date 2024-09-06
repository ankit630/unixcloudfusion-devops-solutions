aws_region          = "us-east-1"
efs_name            = "my-gitlab-runner-efs"
efs_encrypted       = true
efs_transition_to_ia = "AFTER_30_DAYS"
efs_tags            = {
  Environment = "dev"
  Project     = "gitlab-runner"
}