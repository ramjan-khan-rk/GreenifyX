import User from "../models/User.js";

const single = (index, field) => index.key?.[field] === 1 && Object.keys(index.key).length === 1;

/**
 * Older deployments created plain unique indexes on phone/email, which reject a
 * second user who has no phone (both count as null). Replace them with unique
 * indexes that only apply when the field holds a real string.
 * Returns a list of human-readable changes.
 */
export const repairUserIndexes = async () => {
  const changes = [];
  const collection = User.collection;
  let indexes;
  try {
    indexes = await collection.indexes();
  } catch {
    return changes; // collection does not exist yet
  }

  for (const field of ["phone", "email"]) {
    const current = indexes.find((i) => single(i, field));
    const correct = current?.unique && current?.partialFilterExpression?.[field]?.$type === "string";
    if (correct) continue;
    if (current) {
      await collection.dropIndex(current.name);
      changes.push(`replaced old ${field} index (${current.name})`);
    }
    await collection.createIndex(
      { [field]: 1 },
      { unique: true, name: `${field}_unique_when_set`, partialFilterExpression: { [field]: { $type: "string" } } }
    );
    if (!current) changes.push(`added ${field} index`);
  }
  return changes;
};
