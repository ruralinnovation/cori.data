#!/usr/bin/env node
import * as cdk from "aws-cdk-lib";
import { VendCredentialsStack } from "../lib/vend-credentials-stack";

const app = new cdk.App();

new VendCredentialsStack(app, "CoriDataVendCredentials", {
  // Pinned account and region, deliberately not CDK_DEFAULT_ACCOUNT/REGION.
  // The stack hardcodes an ACM certificate ARN and a ruralinnovation.us
  // domain that exist only in this account and region, so deriving the
  // target from ambient credentials would let a different active AWS
  // profile push this stack somewhere it cannot work. Pinning makes CDK
  // refuse up front with a clear account mismatch instead.
  env: {
    account: "312512371189",
    region: "us-east-1",
  },
  description:
    "Vends short-lived, read-only, bucket-scoped S3 credentials for cori.data.* R packages (DDOPS-74)",
});
