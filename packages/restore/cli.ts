#!/usr/bin/env node
import process from "process";
import { restoreAll, type RestoreOptions } from ".";

type ArgMap = Partial<Record<string, string | boolean>>;

function parseArgs(argv: string[]): ArgMap {
  const args: ArgMap = {};
  for (let i = 0; i < argv.length; i += 1) {
    const current = argv[i];
    if (current === "--backup-dir" && argv[i + 1]) {
      args.backupDir = argv[i + 1];
      i += 1;
    } else if (current === "--backup-root" && argv[i + 1]) {
      args.backupRoot = argv[i + 1];
      i += 1;
    } else if (current === "--documents" && argv[i + 1]) {
      args.documentsPath = argv[i + 1];
      i += 1;
    } else if (current === "--wipe-neo4j") {
      args.wipeNeo4j = true;
    } else if (current === "--help" || current === "-h") {
      args.help = true;
    }
  }
  return args;
}

function printHelp() {
  // eslint-disable-next-line no-console
  console.log(`dmf7 restore

Options:
  --backup-dir <path>   Path to a specific backup directory
  --backup-root <path>  Root path containing dated backup folders (default: /data/backups)
  --documents <path>    Destination path for restoring documents
  --wipe-neo4j          Detach delete all existing nodes before restore
  -h, --help            Show this help message
`);
}

async function run() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help) {
    printHelp();
    process.exit(0);
  }

  const restoreOptions: RestoreOptions = { wipeNeo4j: args.wipeNeo4j === true };

  if (typeof args.backupDir === "string") {
    restoreOptions.backupDir = args.backupDir;
  }
  if (typeof args.backupRoot === "string") {
    restoreOptions.backupRoot = args.backupRoot;
  }
  if (typeof args.documentsPath === "string") {
    restoreOptions.documentsPath = args.documentsPath;
  }

  try {
    const result = await restoreAll(restoreOptions);

    // eslint-disable-next-line no-console
    console.log(
      `Restore completed from ${result.backupDir}. Restored: ${result.restored.join(
        ", ",
      ) || "none"}. Skipped: ${result.skipped.join(", ") || "none"}.`,
    );
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(`Restore failed: ${(error as Error).message}`);
    process.exit(1);
  }
}

void run();
