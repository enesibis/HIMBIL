import express from "express";
import request from "supertest";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { registerMonitorRoutes } from "../monitorRoutes.js";

describe("monitor routes", () => {
  const originalToken = process.env.HIMBIL_ADMIN_TOKEN;

  afterEach(() => {
    process.env.HIMBIL_ADMIN_TOKEN = originalToken;
  });

  it("is not mounted at all when HIMBIL_ADMIN_TOKEN is unset", async () => {
    delete process.env.HIMBIL_ADMIN_TOKEN;
    const app = express();
    registerMonitorRoutes(app);

    const response = await request(app).get("/admin");
    expect(response.status).toBe(404);
  });

  describe("with HIMBIL_ADMIN_TOKEN set", () => {
    let app: express.Express;

    beforeEach(() => {
      process.env.HIMBIL_ADMIN_TOKEN = "secret-token";
      app = express();
      registerMonitorRoutes(app);
    });

    it("rejects requests with no token as 404", async () => {
      const response = await request(app).get("/admin");
      expect(response.status).toBe(404);
    });

    it("rejects requests with the wrong token as 404", async () => {
      const response = await request(app).get("/admin?token=wrong");
      expect(response.status).toBe(404);
    });

    // The exact success status is monitor()'s own router internals (e.g. it
    // 301-redirects "/admin" to "/admin/") — what this gate is responsible
    // for is letting an authenticated request past the 404 wall at all.
    it("accepts the correct token as a query param", async () => {
      const response = await request(app).get("/admin?token=secret-token");
      expect(response.status).not.toBe(404);
    });

    it("accepts the correct token as a Bearer header", async () => {
      const response = await request(app).get("/admin").set("Authorization", "Bearer secret-token");
      expect(response.status).not.toBe(404);
    });
  });
});
