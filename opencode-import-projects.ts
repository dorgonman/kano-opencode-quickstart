#!/usr/bin/env bun
/**
 * OpenCode Project & Workspace Import Tool
 * 
 * 匯入專案和 workspace 設定
 * 
 * Usage:
 *   bun run opencode-import-projects.ts projects-backup.json
 *   bun run opencode-import-projects.ts projects-backup.json --merge
 */

import { join } from "path"
import { homedir } from "os"
import { existsSync } from "fs"
import { mkdir } from "fs/promises"

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
  const customDir = process.env.OPENCODE_CONFIG_DIR
  if (customDir) {
    return join(customDir, "storage")
  }

  const xdgData = process.env.XDG_DATA_HOME || join(homedir(), ".local", "share")
  return join(xdgData, "opencode", "storage")
}

async function importProjects(
  storagePath: string, 
  projects: ProjectInfo[], 
  merge: boolean
): Promise<void> {
  const projectDir = join(storagePath, "project")
  
  await mkdir(projectDir, { recursive: true })

  let imported = 0
  let skipped = 0

  for (const project of projects) {
    const projectFile = join(projectDir, `${project.id}.json`)
    
    if (existsSync(projectFile) && !merge) {
      console.error(`  ⏭️  Skipping existing project: ${project.name || project.id}`)
      skipped++
      continue
    }

    // Update timestamp
    const updatedProject = {
      ...project,
      time: {
        ...project.time,
        updated: Date.now(),
      },
    }

    await Bun.write(projectFile, JSON.stringify(updatedProject, null, 2))
    console.error(`  ✅ Imported: ${project.name || project.id}`)
    imported++
  }

  console.error(`\n📊 Summary: ${imported} imported, ${skipped} skipped`)
}

async function importLocalStorage(data: Record<string, string>): Promise<void> {
  console.error("\n⚠️  localStorage import must be done manually in the browser:")
  console.error("\n1. Open OpenCode in your browser")
  console.error("2. Press F12 to open DevTools")
  console.error("3. Go to Console tab")
  console.error("4. Paste and run this code:\n")
  
  console.error("const backup = " + JSON.stringify(data, null, 2) + ";")
  console.error(`
Object.entries(backup).forEach(([k, v]) => {
  try {
    localStorage.setItem(k, v);
  } catch (e) {
    console.error('Failed to set', k, e);
  }
});
console.log('✅ localStorage imported! Reload the page.');
  `)
}

async function main() {
  const args = process.argv.slice(2)
  
  if (args.length === 0) {
    console.error("Usage: bun run opencode-import-projects.ts <backup-file.json> [--merge]")
    console.error("\nOptions:")
    console.error("  --merge    Overwrite existing projects")
    process.exit(1)
  }

  const backupFile = args[0]
  const merge = args.includes("--merge")

  console.error("📥 OpenCode Project Import Tool\n")

  if (!existsSync(backupFile)) {
    console.error(`❌ Backup file not found: ${backupFile}`)
    process.exit(1)
  }

  console.error(`📂 Reading backup: ${backupFile}`)
  const exportData: ExportData = await Bun.file(backupFile).json()

  console.error(`📅 Backup created: ${new Date(exportData.exportedAt).toLocaleString()}`)
  console.error(`📦 Projects in backup: ${exportData.projects.length}\n`)

  const storagePath = await getStoragePath()
  console.error(`📁 Target storage: ${storagePath}\n`)

  await mkdir(storagePath, { recursive: true })

  console.error("🔄 Importing projects...")
  await importProjects(storagePath, exportData.projects, merge)

  if (exportData.localStorage) {
    await importLocalStorage(exportData.localStorage)
  }

  console.error("\n✅ Import complete!")
  console.error("\n💡 Next steps:")
  console.error("   1. If using web version, import localStorage manually (see above)")
  console.error("   2. Restart OpenCode")
  console.error("   3. Your projects should appear in the sidebar")
}

main().catch((error) => {
  console.error("❌ Error:", error)
  process.exit(1)
})
