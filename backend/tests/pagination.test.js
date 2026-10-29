import assert from "node:assert/strict";
import { test } from "node:test";
import { parsePagination } from "../utils/pagination.js";

test("parsePagination uses defaults and clamps", () => {
  assert.deepEqual(parsePagination({}), { page: 1, limit: 20, skip: 0 });
  assert.deepEqual(parsePagination({ page: "2", limit: "10" }), {
    page: 2,
    limit: 10,
    skip: 10,
  });
  assert.equal(parsePagination({ limit: "999" }).limit, 50);
  assert.equal(parsePagination({ page: "-3" }).page, 1);
});
