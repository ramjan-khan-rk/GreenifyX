import assert from "node:assert/strict";
import { test } from "node:test";
import { scriptOf, translatable, translationPrompt, validTarget } from "../utils/translate.js";

test("script detection", () => {
  assert.equal(scriptOf("Planted a ghaf today"), "latin");
  assert.equal(scriptOf("زرعت شجرة اليوم"), "arabic");
  assert.equal(scriptOf("आज पेड़ लगाया"), "devanagari");
  assert.equal(scriptOf("ഇന്ന് മരം നട്ടു"), "malayalam");
  assert.equal(scriptOf("🌱🌱"), "other");
});

test("only real words are worth translating", () => {
  assert.equal(translatable("#ghaf @sara 🌱 https://x.y/z"), false);
  assert.equal(translatable("Beach clean-up #dubai"), true);
});

test("targets and prompt", () => {
  assert.equal(validTarget("ml"), true);
  assert.equal(validTarget("fr"), false);
  assert.equal(validTarget("__proto__"), false);
  assert.match(translationPrompt("hi", "ar"), /into Arabic/);
});
