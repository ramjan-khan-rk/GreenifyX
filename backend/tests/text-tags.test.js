import test from "node:test";
import assert from "node:assert/strict";
import { extractHashtags, extractMentionTokens, resolveMentions } from "../utils/textTags.js";

test("hashtags are found, lower-cased and de-duplicated (Arabic too)", () => {
  assert.deepEqual(extractHashtags("Morning at JBR #BeachCleanUAE #beachcleanuae #زراعة"), ["beachcleanuae", "زراعة"]);
  assert.deepEqual(extractHashtags("email me a#b or #x"), []);
});

test("mentions resolve by full name, or unique first name", () => {
  const people = [
    { _id: "1", name: "Sara Haddad" },
    { _id: "2", name: "Omar Al Suwaidi" },
    { _id: "3", name: "Omar Khalil" },
  ];
  const tokens = extractMentionTokens("Thanks @Sara and @Omar_Khalil and @Omar!");
  assert.deepEqual(tokens, ["sara", "omar khalil", "omar"]);
  assert.deepEqual(resolveMentions(tokens, people).sort(), ["1", "3"]);
});
