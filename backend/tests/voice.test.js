import test from "node:test";
import assert from "node:assert/strict";
import { parseCommand, resolvePerson } from "../utils/voice.js";

test("Hey Greeny commands parse into actions", () => {
  assert.deepEqual(parseCommand("Hey Greeny, chat with Ramjan Khan"), { intent: "open_chat", person: "ramjan khan" });
  assert.deepEqual(parseCommand("hey greeny call ramjan"), { intent: "call", person: "ramjan", video: false });
  assert.deepEqual(parseCommand("Greeny video call Sara"), { intent: "call", person: "sara", video: true });
  assert.deepEqual(parseCommand("send Omar a message saying I'm on my way"), { intent: "send_message", person: "omar a message", message: "i'm on my way" });
  assert.deepEqual(parseCommand("text Omar saying see you at the beach"), { intent: "send_message", person: "omar", message: "see you at the beach" });
  assert.deepEqual(parseCommand("open my rewards"), { intent: "open_screen", screen: "rewards" });
  assert.deepEqual(parseCommand("how many points do I have"), { intent: "points" });
  assert.deepEqual(parseCommand("take me to the eco map"), { intent: "open_screen", screen: "map" });
  assert.equal(parseCommand("اتصل بسارة").intent, "call");
});

test("spoken names match friends, including small speech errors", () => {
  const friends = [{ _id: "1", name: "Ramjan Khan" }, { _id: "2", name: "Sara Haddad" }, { _id: "3", name: "Omar Al Suwaidi" }];
  assert.equal(resolvePerson("ramjan khan", friends)._id, "1");
  assert.equal(resolvePerson("ramzan", friends)._id, "1");
  assert.equal(resolvePerson("sarah", friends)._id, "2");
  assert.equal(resolvePerson("omar a message", friends)._id, "3");
  assert.equal(resolvePerson("zzz", friends), null);
});
