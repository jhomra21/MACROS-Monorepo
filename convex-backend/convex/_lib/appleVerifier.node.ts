import {
  Environment, SignedDataVerifier,
  type JWSTransactionDecodedPayload, type JWSRenewalInfoDecodedPayload, type ResponseBodyV2DecodedPayload,
} from "@apple/app-store-server-library";
import { appleRootG3 } from "../appleRoots/root";

const BUNDLE_ID = "juan-test.cal-macro-tracker";

type Verifier = Pick<SignedDataVerifier, "verifyAndDecodeTransaction" | "verifyAndDecodeRenewalInfo" | "verifyAndDecodeNotification">;

type AppleEnvironment = "Production" | "Sandbox";

function environmentFromUnverifiedPayload(jws: string, notification: boolean): AppleEnvironment {
  if (jws.length > 100_000 || jws.split(".").length !== 3) throw new Error("Invalid JWS.");
  // This untrusted claim is used ONLY for routing. Apple's verifier authenticates it.
  const payload = JSON.parse(Buffer.from(jws.split(".")[1], "base64url").toString("utf8"));
  const environment = notification ? payload.data?.environment : payload.environment;

  if (environment !== "Production" && environment !== "Sandbox") throw new Error("Unsupported Apple environment.");

  return environment;
}

export class AppleVerifier {
  private readonly production: Verifier;
  private readonly sandbox: Verifier;

  constructor(factory: (environment: AppleEnvironment) => Verifier = environment =>
    new SignedDataVerifier(
      [Buffer.from(appleRootG3, "base64")], false,
      environment === "Production" ? Environment.PRODUCTION : Environment.SANDBOX,
      BUNDLE_ID, environment === "Production" ? 6767565938 : undefined,
    )) {
    this.production = factory("Production");
    this.sandbox = factory("Sandbox");
  }

  private route(jws: string, notification = false): Verifier {
    return environmentFromUnverifiedPayload(jws, notification) === "Production" ? this.production : this.sandbox;
  }

  async transaction(jws: string): Promise<JWSTransactionDecodedPayload> {
    const value = await this.route(jws).verifyAndDecodeTransaction(jws);

    if (value.bundleId !== BUNDLE_ID) throw new Error("Invalid Apple bundle.");

    return value;
  }

  async renewal(jws: string): Promise<JWSRenewalInfoDecodedPayload> {
    return await this.route(jws).verifyAndDecodeRenewalInfo(jws);
  }

  async notification(jws: string): Promise<ResponseBodyV2DecodedPayload> {
    return await this.route(jws, true).verifyAndDecodeNotification(jws);
  }
}
