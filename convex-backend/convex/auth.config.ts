export default {
  providers: [
    {
      type: "customJwt",
      applicationID: "macros-convex-dev",
      issuer: "https://macros-auth.jhonra121.workers.dev",
      jwks: "https://macros-auth.jhonra121.workers.dev/.well-known/jwks.json",
      algorithm: "RS256",
    },
  ],
};
