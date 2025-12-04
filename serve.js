#!/usr/bin/env node
/**
 * Simple HTTP server for local development
 * Usage: node serve.js [port]
 * Default port: 8000
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

// Change to the directory where this script is located (like Python server does)
// __dirname is available in CommonJS modules
const scriptDir = __dirname || path.dirname(require.main.filename);
process.chdir(scriptDir);

const PORT = process.argv[2] ? parseInt(process.argv[2]) : 8000;

const MIME_TYPES = {
    '.html': 'text/html',
    '.js': 'application/javascript',
    '.css': 'text/css',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon'
};

const server = http.createServer((req, res) => {
    // Add CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    // Parse the URL and resolve the file path
    // Remove leading slash and handle root path
    let urlPath = req.url === '/' ? 'index.local.html' : req.url.replace(/^\/+/, '');
    let filePath = path.join(process.cwd(), urlPath);
    
    // Security: prevent directory traversal attacks
    const resolvedPath = path.resolve(filePath);
    const basePath = path.resolve(process.cwd());
    if (!resolvedPath.startsWith(basePath)) {
        res.writeHead(403, { 'Content-Type': 'text/html' });
        res.end('<h1>403 - Forbidden</h1>', 'utf-8');
        return;
    }

    const extname = String(path.extname(filePath)).toLowerCase();
    const contentType = MIME_TYPES[extname] || 'application/octet-stream';

    fs.readFile(filePath, (error, content) => {
        if (error) {
            if (error.code === 'ENOENT') {
                // Handle favicon.ico gracefully (browsers request it automatically)
                if (req.url === '/favicon.ico' || urlPath === 'favicon.ico') {
                    res.writeHead(204); // No Content
                    res.end();
                    return;
                }
                console.log(`[404] ${req.url} -> ${filePath}`);
                res.writeHead(404, { 'Content-Type': 'text/html' });
                res.end('<h1>404 - File Not Found</h1>', 'utf-8');
            } else {
                console.error(`[500] Error serving ${req.url}:`, error);
                res.writeHead(500);
                res.end(`Server Error: ${error.code}`, 'utf-8');
            }
        } else {
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content, 'utf-8');
        }
    });
});

server.listen(PORT, () => {
    const url = `http://localhost:${PORT}/index.local.html`;
    // This line is detected by VS Code's serverReadyAction
    console.log(`Server running at http://localhost:${PORT}/`);
    console.log("=".repeat(60));
    console.log("🚀 SERVER STARTED SUCCESSFULLY!");
    console.log("=".repeat(60));
    console.log(`📄 Application URL: ${url}`);
    console.log("⏹️  Press Ctrl+C to stop the server");
    console.log("=".repeat(60));
    
    // Open Chrome browser automatically
    const isWindows = process.platform === 'win32';
    const isMac = process.platform === 'darwin';
    const isLinux = process.platform === 'linux';
    
    // Add a small delay to ensure server is fully ready before opening browser
    setTimeout(() => {
        let command;
        if (isWindows) {
            // Try multiple methods to open Chrome on Windows
            // Method 1: Try common Chrome installation paths
            const chromePaths = [
                process.env.LOCALAPPDATA + '\\Google\\Chrome\\Application\\chrome.exe',
                'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
                'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe'
            ];
            
            // Try to find Chrome and open it
            let chromeFound = false;
            for (const chromePath of chromePaths) {
                if (fs.existsSync(chromePath)) {
                    command = `"${chromePath}" "${url}"`;
                    chromeFound = true;
                    break;
                }
            }
            
            // Fallback: try start command (works if Chrome is in PATH)
            if (!chromeFound) {
                command = `start chrome "${url}"`;
            }
        } else if (isMac) {
            command = `open -a "Google Chrome" "${url}"`;
        } else if (isLinux) {
            command = `google-chrome "${url}" || chromium-browser "${url}" || xdg-open "${url}"`;
        }
        
        if (command) {
            exec(command, (error) => {
                if (error) {
                    // Silently fail if Chrome can't be opened - user can still access manually
                    console.log(`\n💡 Tip: Open ${url} in your browser manually`);
                } else {
                    console.log(`\n🌐 Opening Chrome browser...`);
                }
            });
        }
    }, 1000); // 1 second delay to ensure server is fully ready
});

