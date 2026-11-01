/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";
import type * as _lib_purchasePolicy from "../_lib/purchasePolicy.js";
import type * as appleRoots_root from "../appleRoots/root.js";
import type * as appleVerification from "../appleVerification.js";
import type * as authHelpers from "../authHelpers.js";
import type * as bootstrap from "../bootstrap.js";
import type * as crons from "../crons.js";
import type * as entitlementRecords from "../entitlementRecords.js";
import type * as entitlements from "../entitlements.js";
import type * as foodCleanup from "../foodCleanup.js";
import type * as foodSharing from "../foodSharing.js";
import type * as http from "../http.js";
import type * as proModel from "../proModel.js";
import type * as profileDeletion from "../profileDeletion.js";
import type * as quotas from "../quotas.js";
import type * as sharing from "../sharing.js";
import type * as sharingModel from "../sharingModel.js";
import type * as sharingValidators from "../sharingValidators.js";

/**
 * A utility for referencing Convex functions in your app's API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
declare const fullApi: ApiFromModules<{
  "_lib/purchasePolicy": typeof _lib_purchasePolicy;
  "appleRoots/root": typeof appleRoots_root;
  appleVerification: typeof appleVerification;
  authHelpers: typeof authHelpers;
  bootstrap: typeof bootstrap;
  crons: typeof crons;
  entitlementRecords: typeof entitlementRecords;
  entitlements: typeof entitlements;
  foodCleanup: typeof foodCleanup;
  foodSharing: typeof foodSharing;
  http: typeof http;
  proModel: typeof proModel;
  profileDeletion: typeof profileDeletion;
  quotas: typeof quotas;
  sharing: typeof sharing;
  sharingModel: typeof sharingModel;
  sharingValidators: typeof sharingValidators;
}>;
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;
