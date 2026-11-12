import User from "../models/User.js";

const sameKey = (index, field) =>
  index.key?.[field] === 1 && Object.keys(index.key).length === 1;

export const ensureUserIndexes = async () => {
  const collection = User.collection;
  const indexes = await collection.indexes();

  const emailIndex = indexes.find((index) => sameKey(index, "email"));
  if (!emailIndex) {
    await collection.createIndex(
      { email: 1 },
      { unique: true, sparse: true, name: "email_1_sparse" }
    );
  }

  const phoneIndex = indexes.find((index) => sameKey(index, "phone"));
  if (!phoneIndex) {
    await collection.createIndex(
      { phone: 1 },
      { unique: true, sparse: true, name: "phone_1_sparse" }
    );
    return;
  }

  if (phoneIndex.unique && !phoneIndex.sparse && !phoneIndex.partialFilterExpression) {
    console.warn(
      "User.phone unique index blocks users without a phone. Run `npm run create-admin` or `npm run seed:demo` once to repair it."
    );
  }
};
