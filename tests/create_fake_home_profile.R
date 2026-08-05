# Startup profile for testing connect_to_s3()'s credential-vending fallback
# in isolation from local AWS credentials.
#
# has_local_aws_credentials() checks AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY/
# AWS_SESSION_TOKEN and ~/.aws/credentials -- nothing else (deliberately not
# ~/.aws/config, SSO, or instance-role credentials; see its docstring). To
# force the vended-credentials path without touching real credentials:
# unset those env vars, blank the files the AWS CLI/SDK would otherwise
# fall back to, and point HOME at an empty directory. DuckDB's own internal
# home-directory resolution errors if that directory doesn't exist yet, so
# this file is loaded as R_PROFILE_USER to create it before any DuckDB call
# runs, while still leaving you in a normal interactive session:
#
#   env -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN \
#       AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_CONFIG_FILE=/dev/null \
#       HOME=/tmp/fake_home \
#       R_PROFILE_USER=tests/create_fake_home_profile.R \
#       R
#
# Then, inside the session:
#   devtools::load_all()
#   con <- connect_to_s3("cori.data.qcew")

dir.create(Sys.getenv("HOME"), showWarnings = FALSE, recursive = TRUE)
