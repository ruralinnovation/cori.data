import {
  Stack,
  StackProps,
  Duration,
  CfnOutput,
  RemovalPolicy,
} from "aws-cdk-lib";
import { Construct } from "constructs";
import * as iam from "aws-cdk-lib/aws-iam";
import * as acm from "aws-cdk-lib/aws-certificatemanager";
import * as apigwv2 from "aws-cdk-lib/aws-apigatewayv2";
import { HttpLambdaIntegration } from "aws-cdk-lib/aws-apigatewayv2-integrations";
import { NodejsFunction } from "aws-cdk-lib/aws-lambda-nodejs";
import { Runtime } from "aws-cdk-lib/aws-lambda";
import * as logs from "aws-cdk-lib/aws-logs";
import * as path from "path";

// Buckets the endpoint will vend read-only credentials for. This list is the
// access-control boundary: the handler rejects anything not named here before
// STS is ever called.
const ALLOWED_BUCKETS = [
  "cori.data.bds",
  "cori.data.bps",
  "cori.data.census",
  "cori.data.fcc",
  "cori.data.ipeds",
  "cori.data.patents",
  "cori.data.pep",
  "cori.data.qcew",
  "cori.data.vacancy",
  "cori.data.verse",
  "ruraldefinitions"
];

const DOMAIN_NAME = "data.ruralinnovation.us";

// Wildcard cert for *.ruralinnovation.us. Covers exactly one label, which is
// why the endpoint is data.ruralinnovation.us and not a deeper subdomain.
const CERTIFICATE_ARN =
  "arn:aws:acm:us-east-1:312512371189:certificate/de6d1dc8-71f0-473e-83bf-a522d8eea219";

// Every mutating S3 action, denied outright on the vended role. An explicit
// Deny in IAM always beats any Allow, so this holds even if someone later
// widens the permissions policy below by mistake.
const S3_WRITE_ACTIONS = [
  "s3:PutObject",
  "s3:PutObjectAcl",
  "s3:PutObjectTagging",
  "s3:DeleteObject",
  "s3:DeleteObjectTagging",
  "s3:DeleteObjectVersion",
  "s3:RestoreObject",
  "s3:AbortMultipartUpload",
  "s3:CreateBucket",
  "s3:DeleteBucket",
  "s3:PutBucketAcl",
  "s3:PutBucketPolicy",
  "s3:DeleteBucketPolicy",
  "s3:PutBucketVersioning",
  "s3:PutLifecycleConfiguration",
  "s3:ReplicateObject",
  "s3:ReplicateDelete",
];

export class VendCredentialsStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // ---------------------------------------------------------------------
    // IAM
    // ---------------------------------------------------------------------

    // Execution role for the vending Lambda itself -- no direct S3
    // permissions, it can only log and assume the target role below.
    const lambdaRole = new iam.Role(this, "VendCredentialsLambdaRole", {
      assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName(
          "service-role/AWSLambdaBasicExecutionRole"
        ),
      ],
    });

    // The role actually vended to callers. Read-only across ALLOWED_BUCKETS
    // is the ceiling; each vended credential is narrowed further to a single
    // bucket by the inline session policy the handler attaches per-request.
    const targetRole = new iam.Role(this, "CoriDataS3ReaderRole", {
      assumedBy: new iam.ArnPrincipal(lambdaRole.roleArn),
      maxSessionDuration: Duration.hours(1),
    });

    targetRole.addToPolicy(
      new iam.PolicyStatement({
        actions: ["s3:GetObject"],
        resources: ALLOWED_BUCKETS.map((b) => `arn:aws:s3:::${b}/*`),
      })
    );
    targetRole.addToPolicy(
      new iam.PolicyStatement({
        actions: ["s3:ListBucket"],
        resources: ALLOWED_BUCKETS.map((b) => `arn:aws:s3:::${b}`),
      })
    );

    // Defense in depth: no write, ever, on any bucket -- not just the ones
    // above. Read access is granted by exception; mutation is denied globally.
    targetRole.addToPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.DENY,
        actions: S3_WRITE_ACTIONS,
        resources: ["*"],
      })
    );

    lambdaRole.addToPolicy(
      new iam.PolicyStatement({
        actions: ["sts:AssumeRole"],
        resources: [targetRole.roleArn],
      })
    );

    // ---------------------------------------------------------------------
    // Lambda
    // ---------------------------------------------------------------------

    const fn = new NodejsFunction(this, "VendCredentialsFunction", {
      entry: path.join(__dirname, "../lambda/index.ts"),
      handler: "handler",
      runtime: Runtime.NODEJS_22_X,
      role: lambdaRole,
      timeout: Duration.seconds(10),
      memorySize: 256,
      // Per-request audit trail. The handler logs one structured line per
      // call (bucket, session name, source IP, caller tag), which is the
      // record of who asked for what -- CloudTrail separately records the
      // matching sts:AssumeRole under the same session name.
      //
      // Retention is set declaratively here rather than via the `logRetention`
      // prop; that prop provisions an extra custom-resource Lambda to make a
      // single PutRetentionPolicy call at deploy time. Same retention, one
      // less moving part -- log capture is unaffected either way.
      logGroup: new logs.LogGroup(this, "VendCredentialsLogGroup", {
        retention: logs.RetentionDays.ONE_YEAR,
        // RETAIN, not DESTROY: tearing down the stack must not take the
        // usage-tracking history with it.
        removalPolicy: RemovalPolicy.RETAIN,
      }),
      environment: {
        TARGET_ROLE_ARN: targetRole.roleArn,
        ALLOWED_BUCKETS: ALLOWED_BUCKETS.join(","),
      },
      bundling: {
        minify: true,
        sourceMap: true,
        // Bundle @aws-sdk/client-sts rather than relying on the runtime's
        // built-in SDK, so a Lambda runtime upgrade can't silently shift
        // STS behavior underneath us.
        externalModules: [],
      },
    });

    // ---------------------------------------------------------------------
    // Custom domain + HTTP API
    //
    // Lambda Function URLs do not support custom domains, so this is an
    // API Gateway HTTP API instead. That also gives us request throttling,
    // which matters because the endpoint is intentionally unauthenticated.
    // ---------------------------------------------------------------------

    const certificate = acm.Certificate.fromCertificateArn(
      this,
      "WildcardCertificate",
      CERTIFICATE_ARN
    );

    const domainName = new apigwv2.DomainName(this, "VendCredentialsDomain", {
      domainName: DOMAIN_NAME,
      certificate,
    });

    const api = new apigwv2.HttpApi(this, "VendCredentialsApi", {
      description: "Vends short-lived, read-only, bucket-scoped S3 credentials",
      defaultDomainMapping: { domainName },
    });

    api.addRoutes({
      path: "/credentials",
      methods: [apigwv2.HttpMethod.GET],
      integration: new HttpLambdaIntegration("VendCredentialsIntegration", fn),
    });

    // Throttle the default stage. The endpoint is public and unauthenticated,
    // so this is the guard against runaway invocation cost.
    const defaultStage = api.defaultStage!.node
      .defaultChild as apigwv2.CfnStage;
    defaultStage.defaultRouteSettings = {
      throttlingRateLimit: 20, // steady-state requests/sec
      throttlingBurstLimit: 40,
    };

    // ---------------------------------------------------------------------
    // DNS
    //
    // ruralinnovation.us is registered at Hover, not Route53, and every
    // existing *.ruralinnovation.us subdomain (bcat, finance, map, ...) is a
    // flat CNAME added directly in Hover's DNS editor -- there is no
    // per-subdomain Route53 zone/NS-delegation pattern in use here. This
    // matches that: no hosted zone, just the regional domain name as a
    // CNAME target for whoever manages the Hover DNS editor to add by hand.
    // ---------------------------------------------------------------------

    // ---------------------------------------------------------------------
    // Outputs
    // ---------------------------------------------------------------------

    new CfnOutput(this, "VendingUrl", {
      description: "Pass this to cori.data::connect_to_s3(vending_url = ...)",
      value: `https://${DOMAIN_NAME}/credentials`,
    });

    new CfnOutput(this, "ExecuteApiUrl", {
      description:
        "Direct API Gateway URL; works immediately, no DNS required",
      value: `${api.apiEndpoint}/credentials`,
    });

    new CfnOutput(this, "CnameTarget", {
      description:
        `In Hover's DNS editor for ruralinnovation.us: add a CNAME record, ` +
        `Host = "data", Value = this output's value (same pattern as the ` +
        `other *.ruralinnovation.us CNAMEs already there)`,
      value: domainName.regionalDomainName,
    });

    new CfnOutput(this, "TargetRoleArn", { value: targetRole.roleArn });
  }
}
