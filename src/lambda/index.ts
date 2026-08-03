import { STSClient, AssumeRoleCommand } from "@aws-sdk/client-sts";
import type {
  APIGatewayProxyEventV2,
  APIGatewayProxyStructuredResultV2,
} from "aws-lambda";

const sts = new STSClient({});

// Buckets this endpoint will vend access to. Anything else is rejected
// before STS is ever called -- this is the real access-control boundary,
// independent of whatever the target role's own policy allows.
const ALLOWED_BUCKETS = (process.env.ALLOWED_BUCKETS ?? "")
  .split(",")
  .map((b) => b.trim())
  .filter(Boolean);

const TARGET_ROLE_ARN = requireEnv("TARGET_ROLE_ARN");
const REGION = process.env.AWS_REGION ?? "us-east-1";
const SESSION_DURATION_SECONDS = 900; // 15 min -- STS minimum

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

// Read-only, single-bucket inline session policy -- a *further* restriction
// on top of whatever TARGET_ROLE_ARN's own policy already grants.
function buildSessionPolicy(bucket: string): string {
  return JSON.stringify({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: ["s3:GetObject"],
        Resource: `arn:aws:s3:::${bucket}/*`,
      },
      {
        Effect: "Allow",
        Action: ["s3:ListBucket"],
        Resource: `arn:aws:s3:::${bucket}`,
      },
    ],
  });
}

// RoleSessionName: 2-64 chars, [\w+=,.@-]. Embeds a timestamp + optional
// caller tag so individual calls are distinguishable in CloudTrail.
function buildSessionName(callerTag?: string): string {
  const ts = Date.now();
  const safeTag = (callerTag ?? "anon").replace(/[^\w.@-]/g, "").slice(0, 20);
  return `coridata-${safeTag}-${ts}`.slice(0, 64);
}

export const handler = async (
  event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyStructuredResultV2> => {
  const bucket = event.queryStringParameters?.bucket;
  const callerTag = event.queryStringParameters?.caller;
  const sourceIp = event.requestContext?.http?.sourceIp ?? "unknown";

  if (!bucket) {
    return json(400, { error: "Missing required query parameter: bucket" });
  }

  if (!ALLOWED_BUCKETS.includes(bucket)) {
    console.warn(
      JSON.stringify({
        event: "vend_credentials_rejected",
        reason: "bucket_not_allowed",
        bucket,
        sourceIp,
        callerTag,
      })
    );
    return json(403, { error: `Bucket not permitted: ${bucket}` });
  }

  const sessionName = buildSessionName(callerTag);

  try {
    const result = await sts.send(
      new AssumeRoleCommand({
        RoleArn: TARGET_ROLE_ARN,
        RoleSessionName: sessionName,
        Policy: buildSessionPolicy(bucket),
        DurationSeconds: SESSION_DURATION_SECONDS,
      })
    );

    const creds = result.Credentials;
    if (!creds?.AccessKeyId || !creds.SecretAccessKey || !creds.SessionToken) {
      throw new Error("AssumeRole returned incomplete credentials");
    }

    console.log(
      JSON.stringify({
        event: "vend_credentials_issued",
        bucket,
        sessionName,
        sourceIp,
        callerTag,
        expiration: creds.Expiration,
      })
    );

    // Field names here are the contract with cori.data::connect_to_s3().
    // Changing them breaks every R caller.
    return json(200, {
      access_key_id: creds.AccessKeyId,
      secret_access_key: creds.SecretAccessKey,
      session_token: creds.SessionToken,
      region: REGION,
      expiration: creds.Expiration,
    });
  } catch (err) {
    console.error(
      JSON.stringify({
        event: "vend_credentials_error",
        bucket,
        sourceIp,
        error: err instanceof Error ? err.message : String(err),
      })
    );
    return json(500, { error: "Failed to issue credentials" });
  }
};

function json(
  statusCode: number,
  body: unknown
): APIGatewayProxyStructuredResultV2 {
  return {
    statusCode,
    headers: {
      "content-type": "application/json",
      // Credentials must never be cached by any intermediary.
      "cache-control": "no-store",
    },
    body: JSON.stringify(body),
  };
}
