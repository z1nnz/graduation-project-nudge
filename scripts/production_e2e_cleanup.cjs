"use strict";

const FIRESTORE_COMMIT_LIMIT = 500;

function buildCleanupDocumentNames(...collections) {
  const names = new Set();
  for (const collection of collections) {
    if (!collection) continue;
    for (const name of collection) {
      if (typeof name !== "string" || name.trim() === "") {
        throw new TypeError("Cleanup document names must be non-empty strings.");
      }
      names.add(name);
    }
  }
  return [...names];
}

function chunkCleanupDocumentNames(
  names,
  maximumWrites = FIRESTORE_COMMIT_LIMIT,
) {
  if (!Number.isInteger(maximumWrites) || maximumWrites < 1) {
    throw new RangeError("maximumWrites must be a positive integer.");
  }
  const uniqueNames = buildCleanupDocumentNames(names);
  const chunks = [];
  for (let index = 0; index < uniqueNames.length; index += maximumWrites) {
    chunks.push(uniqueNames.slice(index, index + maximumWrites));
  }
  return chunks;
}

module.exports = {
  FIRESTORE_COMMIT_LIMIT,
  buildCleanupDocumentNames,
  chunkCleanupDocumentNames,
};
