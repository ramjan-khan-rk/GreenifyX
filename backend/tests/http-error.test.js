import assert from "node:assert/strict";
import { test } from "node:test";
import { sendServerError } from "../utils/httpError.js";

test("sendServerError does not include the exception text", () => {
  let status;
  let body;
  const res = {
    status(code) {
      status = code;
      return this;
    },
    json(payload) {
      body = payload;
      return this;
    },
  };
  sendServerError(res, "Unable to load friends");
  assert.equal(status, 500);
  assert.equal(body.success, false);
  assert.equal(body.message, "Unable to load friends");
  assert.equal(JSON.stringify(body).includes("E11000"), false);
});
