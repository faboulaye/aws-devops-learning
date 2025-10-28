'use strict';

let WARM = false;

function releaseInfo() {
  return {
    version: process.env.RELEASE_VERSION || '0.0.0',
    environment: process.env.STAGE || process.env.ENV || 'dev',
  };
}

function setAndGetColdStart() {
  const wasCold = !WARM;
  WARM = true;
  return wasCold;
}

exports.handler = async (event, context) => {
  const body = {
    message: 'Hello from Lambda!',
    release: releaseInfo(),
    requestId: context && context.awsRequestId ? context.awsRequestId : undefined,
    coldStart: setAndGetColdStart(),
  };
  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  };
};


