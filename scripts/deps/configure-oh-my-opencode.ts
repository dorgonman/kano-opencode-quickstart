
import { join, dirname } from "path";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { homedir, platform } from "os";

interface OpenCodeConfig {
  plugin?: string[];
  [key: string]: any;
}

function getConfigPath(): string {
  if (process.env.OPENCODE_CONFIG) {
    return process.env.OPENCODE_CONFIG;
  }

  // OpenCode uses ~/.config/opencode on all platforms (including Windows)
  const xdgConfig = process.env.XDG_CONFIG_HOME || join(homedir(), ".config");
  return join(xdgConfig, "opencode", "opencode.json");
}

function main() {
  const configPath = getConfigPath();
  const configDir = dirname(configPath);

  console.log(`[configure-oh-my-opencode] Checking config at: ${configPath}`);

  if (!existsSync(configDir)) {
    console.log(`[configure-oh-my-opencode] Creating config directory: ${configDir}`);
    mkdirSync(configDir, { recursive: true });
  }

  let config: OpenCodeConfig = {};
  if (existsSync(configPath)) {
    try {
      const content = readFileSync(configPath, "utf-8");
      // Basic JSONC support: remove comments if simple, but standard JSON.parse might fail on comments.
      // For now, assume relatively standard JSON or try to parse.
      // If it fails, we might overwite or warn. Let's try to be safe.
      config = JSON.parse(content);
    } catch (e) {
      console.warn(`[configure-oh-my-opencode] Warning: Failed to parse existing config. Starting fresh or aborting?`);
      console.warn(`Error: ${e}`);
      // If we can't parse it, we probably shouldn't blindly overwrite it in a real scenario,
      // but for this fix, let's assume valid JSON or empty.
      // If it allows comments (JSONC), standard JSON.parse fails.
      // We will try to use a regex to strip comments if simple parse fails?
      // Or just warn and append?
      // For this task, let's assume standard JSON usage or empty.
      // If the user has a complex comment-heavy file, we might break it.
      // Let's stop if we can't parse, to be safe.
      console.error("ABORTING: Cannot parse opencode.json. Please add 'oh-my-opencode' to 'plugin' list manually.");
      process.exit(1);
    }
  }

  const plugins = config.plugin || [];
  if (!plugins.includes("oh-my-opencode")) {
    console.log(`[configure-oh-my-opencode] Adding 'oh-my-opencode' to plugins...`);
    plugins.push("oh-my-opencode");
    config.plugin = plugins;

    writeFileSync(configPath, JSON.stringify(config, null, 2), "utf-8");
    console.log(`[configure-oh-my-opencode] ✓ Configuration updated.`);
  } else {
    console.log(`[configure-oh-my-opencode] 'oh-my-opencode' is already enabled.`);
  }
}

main();
