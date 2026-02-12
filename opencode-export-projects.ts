#!/usr/bin/env bun
/**
 * OpenCode Project & Workspace Export Tool
 * 
 * 匯出所有專案和 workspace 設定（不含 session 對話記錄）
 * 
 * Usage:
 *   bun run opencode-export-projects.ts > projects-backup.json
 *   bun run opencode-export-projects.ts --output projects-backup.json
 */

import { join } from "path"
import { homedir } from "os"
import { existsSync } from "fs"

interface ProjectInfo {
  id: string
  worktree: string
  vcs?: "git"
  name?: string
  icon?: {
    url?: string
    override?: string
    color?: string
  }
  commands?: {
    start?: string
  }
  time: {
    created: number
    updated: number
    initialized?: number
  }
  sandboxes: string[]
}

interface ExportData {
  version: string
  exportedAt: number
  projects: ProjectInfo[]
  localStorage?: Record<string, string>
}

async function getStoragePath(): Promise<string> {
  // Check for custom config dir
  const customDir = process.env.OPENCODE_CONFIG_DIR
  if (customDir) {
    return join(customDir, "storage")
  }

  // Default XDG path
  const xdgData = process.env.XDG_DATA_HOME || join(homedir(), ".local", "share")
  return join(xdgData, "opencode", "storage")
}

async function listProjects(storagePath: string): Promise<ProjectInfo[]> {
  const projectDir = join(storagePath, "project")
  
  if (!existsSync(projectDir)) {
    console.error("❌ Project directory not found:", projectDir)
    return []
  }

  const files = await Array.fromAsync(
    new Bun.Glob("*.json").scan({
      cwd: projectDir,
      onlyFiles: true,
    })
  )

  const projects: ProjectInfo[] = []
  
  for (const file of files) {
    try {
      const content = await Bun.file(join(projectDir, file)).json()
      projects.push(content)
    } catch (error) {
      console.error(`⚠️  Failed to read project file: ${file}`, error)
    }
  }

  return projects
}

async function exportLocalStorage(): Promise<Record<string, string> | undefined> {
  // This function is a placeholder for browser localStorage export
  // In practice, this needs to be run in the browser console
  console.error("\n⚠️  Note: Browser localStorage cannot be exported from Node.js")
  console.error("To export localStorage, run this in your browser console (F12):")
  console.error(`
const backup = {};
for (let i = 0; i < localStorage.length; i++) {
  const key = localStorage.key(i);
  if (key && key.startsWith('opencode.')) {
    backup[key] = localStorage.getItem(key);
  }
}
console.log(JSON.stringify(backup, null, 2));
  `)
  return undefined
}

async function main() {
  const args = process.argv.slice(2)
  const outputFile = args.includes("--output") 
    ? args[args.indexOf("--output") + 1] 
    : undefined

  console.error("🔍 OpenCode Project Export Tool\n")

  const storagePath = await getStoragePath()
  console.error(`📁 Storage path: ${storagePath}\n`)

  if (!existsSync(storagePath)) {
    console.error("❌ Storage directory not found!")
    console.error("Make sure OpenCode has been run at least once.")
    process.exit(1)
  }

  console.error("📦 Reading projects...")
  const projects = await listProjects(storagePath)
  
  console.error(`✅ Found ${projects.length} project(s)\n`)

  for (const project of projects) {
    console.error(`  • ${project.name || project.id}`)
    console.error(`    Worktree: ${project.worktree}`)
    if (project.sandboxes.length > 0) {
      console.error(`    Sandboxes: ${project.sandboxes.length}`)
    }
  }

  const exportData: ExportData = {
    version: "1.0.0",
    exportedAt: Date.now(),
    projects,
    localStorage: await exportLocalStorage(),
  }

  const json = JSON.stringify(exportData, null, 2)

  if (outputFile) {
    await Bun.write(outputFile, json)
    console.error(`\n✅ Exported to: ${outputFile}`)
  } else {
    // Output to stdout
    console.log(json)
  }

  console.error("\n📝 Export complete!")
  console.error("\n💡 To import on another machine:")
  console.error("   bun run opencode-import-projects.ts projects-backup.json")
}

main().catch((error) => {
  console.error("❌ Error:", error)
  process.exit(1)
})
