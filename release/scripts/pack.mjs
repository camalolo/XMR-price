import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import pkg from 'webext-buildtools-chrome-crx-builder';
const ChromeCrxBuilder = pkg.default;

// Private key for CRX signing is stored outside repository at: ../Chrome-Extension-Keys/key.pem

try {
  // Read manifest.json to get version and name
  const manifest = JSON.parse(fs.readFileSync('./manifest.json', 'utf8'));
  const version = manifest.version;
  const extensionName = manifest.name.toLowerCase().replaceAll(/[^a-z0-9]/g, '-').replaceAll(/-+/g, '-').replaceAll(/^-|-$/g, '');

  // Create dist directory if it doesn't exist
  if (!fs.existsSync('./dist')) {
    fs.mkdirSync('./dist');
  }

  // Build the extension using web-ext (creates zip)
   // Generic ignore list for common development files - extensions can customize this
   const ignoreFiles = [
     "dist/",
     "package.json",
     "package-lock.json",
     "eslint.config.mjs",
     "jsconfig.json",
     "pack.mjs",
     "tag_release.sh",
     ".git/",
     ".gitignore",
     "node_modules/",
     "release/"
   ].join('" "');

   execSync(`npx web-ext build --source-dir . --overwrite-dest --ignore-files "${ignoreFiles}"`, { stdio: 'inherit' });

  // Move the generated zip to dist with a cleaner name
  const sourceZip = path.join('web-ext-artifacts', `${extensionName.replaceAll('-', '_')}-${version}.zip`);
  const targetZip = path.join('./dist', `${extensionName}-v${version}.zip`);
  const targetCrx = path.join('./dist', `${extensionName}-v${version}.crx`);

   try {
     // Safe usage: sourceZip path is constructed from manifest.json version and name fields,
     // which are controlled developer inputs read from the extension's own manifest file.
     // No external user input can influence this path, preventing path injection risks.
     // eslint-disable-next-line security/detect-non-literal-fs-filename
     if (fs.existsSync(sourceZip)) {
      fs.copyFileSync(sourceZip, targetZip);
      console.log(`Successfully created ZIP: ${targetZip}`);

      // Also create CRX format for releases (better for users)
      const privateKeyPath = path.resolve('../Chrome-Extension-Keys/key.pem');

       // Read the ZIP file created by web-ext
       // Safe usage: sourceZip path is the same controlled path as above, generated from
       // manifest data during the build process. The file is created by web-ext and verified
       // to exist just above, ensuring no injection vulnerability.
       const zipBuffer = fs.readFileSync(sourceZip); // eslint-disable-line security/detect-non-literal-fs-filename

      // Create CRX using ChromeCrxBuilder
      const builder = new ChromeCrxBuilder({
        privateKeyFilePath: privateKeyPath,
        crxFilePath: targetCrx
      }, console.log);

      builder.setInputZipBuffer(zipBuffer);
      builder.requireCrxFile();

      await builder.build();
      console.log(`Successfully created CRX: ${targetCrx}`);

      // Clean up web-ext artifacts
      const artifactsDirectory = 'web-ext-artifacts';
      if (fs.existsSync(artifactsDirectory)) {
        fs.rmSync(artifactsDirectory, { recursive: true, force: true });
        console.log('Cleaned up web-ext artifacts');
      }
    } else {
      throw new Error(`Generated zip file not found: ${sourceZip}`);
    }

  } catch (error) {
    throw new Error(`CRX creation failed: ${error.message}`);
  }
} catch (error) {
  console.error('Error packing extension:', error.message);
  throw error;
}