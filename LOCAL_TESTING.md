# Local Testing Guide

This guide will help you test the Pool Tracker application locally before deploying to Cloudflare Pages.

## Prerequisites

- A Supabase project with the database schema set up (you've already done this! ✅)
- Python 3.x OR Node.js installed on your computer
- Your Supabase credentials:
  - Project URL (found in Settings > API)
  - Anonymous Key (found in Settings > API)

## Quick Start

### Step 1: Configure Supabase Credentials

1. Open `config.js` in this directory
2. Replace `YOUR_SUPABASE_URL_HERE` with your Supabase project URL
3. Replace `YOUR_SUPABASE_ANON_KEY_HERE` with your Supabase anonymous key

Example:
```javascript
window.SUPABASE_URL = 'https://abcdefghijklmnop.supabase.co';
window.SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

### Step 2: Start the Local Server

Choose one of the following methods:

#### Option A: Using Python (Recommended - Works on Windows, Mac, Linux)

```bash
python serve.py
```

Or specify a custom port:
```bash
python serve.py 3000
```

#### Option B: Using Node.js

```bash
node serve.js
```

Or specify a custom port:
```bash
node serve.js 3000
```

#### Option C: Using Python's Built-in Server (Simplest)

```bash
python -m http.server 8000
```

Then open: `http://localhost:8000/index.local.html`

### Step 3: Open in Browser

Once the server is running, open your browser and navigate to:

```
http://localhost:8000/index.local.html
```

The default port is 8000. If you used a different port, adjust the URL accordingly.

## Testing Checklist

- [ ] Server starts without errors
- [ ] Browser opens the application
- [ ] No configuration errors shown
- [ ] Can sign up a new account
- [ ] Can sign in with created account
- [ ] Can create a new pool
- [ ] Can see the pool in "My Pools" list
- [ ] Can sign out successfully

## Troubleshooting

### "Configuration Error" Message

**Problem:** You see a red error message about missing Supabase credentials.

**Solution:** 
1. Make sure you've edited `config.js` with your actual Supabase URL and key
2. Refresh the browser page
3. Check that the values don't contain `YOUR_` placeholder text

### "Module not found" or "Cannot find module"

**Problem:** Python or Node.js can't find the server script.

**Solution:**
- Make sure you're in the project directory
- Check that `serve.py` or `serve.js` exists in the current directory
- Try using the full path: `python /path/to/serve.py`

### Port Already in Use

**Problem:** You get an error that port 8000 is already in use.

**Solution:**
- Use a different port: `python serve.py 3000`
- Or stop the other application using port 8000

### CORS Errors in Browser Console

**Problem:** You see CORS-related errors in the browser console.

**Solution:**
- Make sure you're accessing via `http://localhost:PORT` and not `file://`
- The server scripts include CORS headers, so this shouldn't happen if using the provided servers

### Database Connection Errors

**Problem:** You see errors about database tables not existing.

**Solution:**
- Verify you've run the migration SQL in Supabase
- Check that your Supabase URL and key are correct
- Make sure RLS policies are set up correctly

## File Structure

```
Pool-Tracker/
├── index.html              # Production version (for Cloudflare)
├── index.local.html        # Local testing version (loads config.js)
├── config.js               # Local Supabase configuration
├── serve.py                # Python local server
├── serve.js                # Node.js local server
└── supabase/
    └── migrations/
        └── 001_initial_schema.sql
```

## Next Steps

Once local testing is successful:

1. **Deploy to Cloudflare Pages:**
   - Upload `index.html` (not `index.local.html`)
   - Set environment variables in Cloudflare Pages:
     - `SUPABASE_URL`
     - `SUPABASE_ANON_KEY`

2. **Test Production Build:**
   - Verify the production version works the same way

## Notes

- `index.local.html` is for local testing only and loads `config.js`
- `index.html` is for production and uses environment variables
- Never commit `config.js` with real credentials to version control
- The local server is for development only, not for production use

