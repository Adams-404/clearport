# Clearport conversation backups

Clearport exports conversations as UTF-8 JSON. Backups are local files chosen by
the user through the platform file picker and are never uploaded by Clearport.

## Format

The top-level object contains:

- \`format\`: \`clearport.conversations\`
- \`version\`: integer schema version, currently \`1\`
- \`exportedAt\`: UTC ISO-8601 timestamp
- \`conversations\`: an array of conversation objects

Each conversation uses the same fields as Clearport's local conversation model:
\`id\`, \`title\`, \`createdAt\`, \`updatedAt\`, and \`messages\`. Message objects
contain \`id\`, \`role\` (\`user\` or \`assistant\`), \`content\`, \`createdAt\`,
and optional boolean \`isError\`.

## Restore behaviour

The importer validates the complete document and schema version before changing
app state. Merge is the default-safe action; if an imported conversation ID
already exists, Clearport assigns a new local ID. Replace is a separate,
explicitly confirmed action and replaces the local conversation collection.
Unknown formats, unsupported versions, duplicate IDs within a backup, and
malformed conversation or message records are rejected.
