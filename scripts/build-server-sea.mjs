import { build } from "esbuild";
import { copyFile, mkdir, rm, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn, exec as nodeExec } from "node:child_process";

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, "..");
const buildDir = resolve(projectRoot, "build", "sea");
const platform = process.platform;
const arch = process.arch;
const binaryExtension = platform === "win32" ? ".exe" : "";

const outputName = `ragmcp-server-${platform}-${arch}${binaryExtension}`;
const entryPath = resolve(projectRoot, "src", "sea-main.ts");
const bundlePath = resolve(buildDir, "sea-entry.cjs");
const blobPath = resolve(buildDir, "ragmcp-server.blob");
const configPath = resolve(buildDir, "sea-config.json");
const targetPath = resolve(buildDir, outputName);
const thinNodePath = resolve(buildDir, `node-${platform}-${arch}${binaryExtension}`);
const postjectPath = resolve(
  projectRoot,
  "node_modules",
  ".bin",
  platform === "win32" ? "postject.cmd" : "postject",
);
// Node.jsの実行パスを取得
const getNodePath = () => {
  return new Promise((resolve, reject) => {
    nodeExec(process.platform === "win32" ? "where node" : "which node", (error, stdout) => {
      if (error) {
        reject(error);
      } else {
        resolve(stdout.trim().split(/\r?\n/)[0].trim());
      }
    });
  });
};

const nodePath = await getNodePath();

const sentinelFuse = "NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2";

await rm(buildDir, { recursive: true, force: true });
await mkdir(buildDir, { recursive: true });

await build({
  entryPoints: [entryPath],
  outfile: bundlePath,
  bundle: true,
  format: "cjs",
  platform: "node",
  target: "node24",
  sourcemap: false,
  minify: false,
  packages: "bundle",
});

await writeFile(
  configPath,
  JSON.stringify(
    {
      main: bundlePath,
      output: blobPath,
      disableExperimentalSEAWarning: true,
      useCodeCache: false,
      useSnapshot: false,
    },
    null,
    2,
  ),
);

await exec(nodePath, ["--experimental-sea-config", configPath], {
  cwd: projectRoot,
});

const sourceBinaryPath = await prepareSourceBinary();
await copyFile(sourceBinaryPath, targetPath);

if (platform === "darwin") {
  await exec("codesign", ["--remove-signature", targetPath], {
    cwd: projectRoot,
  });
}

const postjectArgs = [
  targetPath,
  "NODE_SEA_BLOB",
  blobPath,
  "--sentinel-fuse",
  sentinelFuse,
];
if (platform === "darwin") {
  postjectArgs.push("--macho-segment-name", "NODE_SEA");
}

await exec(postjectPath, postjectArgs, {
  cwd: projectRoot,
});

if (platform === "darwin") {
  await exec("codesign", ["--sign", "-", targetPath], {
    cwd: projectRoot,
  });
}

console.log(targetPath);

async function prepareSourceBinary() {
  if (platform !== "darwin") {
    return nodePath;
  }

  const lipoInfo = await execCapture("lipo", ["-info", process.execPath], {
    cwd: projectRoot,
  });

  if (!lipoInfo.includes("Architectures in the fat file")) {
    return process.execPath;
  }

  await exec("lipo", ["-thin", arch, process.execPath, "-output", thinNodePath], {
    cwd: projectRoot,
  });
  return thinNodePath;
}

function exec(command, args, options = {}) {
  return new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(command, args, {
      stdio: "inherit",
      shell: process.platform === "win32",
      windowsHide: true,
      ...options,
    });

    child.on("error", rejectPromise);
    child.on("close", (code) => {
      if (code === 0) {
        resolvePromise();
        return;
      }
      rejectPromise(new Error(`${command} exited with code ${code}`));
    });
  });
}

function execCapture(command, args, options = {}) {
  return new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(command, args, {
      stdio: ["ignore", "pipe", "pipe"],
      ...options,
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("error", rejectPromise);
    child.on("close", (code) => {
      if (code === 0) {
        resolvePromise(stdout.trim());
        return;
      }
      rejectPromise(new Error(`${command} exited with code ${code}: ${stderr || stdout}`));
    });
  });
}
