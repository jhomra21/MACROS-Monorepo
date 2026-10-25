import worker from "../../worker/usda-proxy/src/index.ts";

export default {
  fetch(request, env, ctx) {
    const throwingBudget = {
      idFromName: () => "usda",
      get: () => ({ acquire: async () => { throw new Error("synthetic budget outage"); } }),
    };

    return worker.fetch(request, { ...env, USDA_BUDGET: throwingBudget }, ctx);
  },
};
