# Emergency Fix for Auth Loop

## Immediate Steps to Stop the Loop

### Option 1: Clear Browser Data (Quickest)
1. Open DevTools (F12)
2. Go to **Application** tab
3. In left sidebar, click **Storage** → **Clear site data**
4. Click **Clear site data** button
5. Close the tab and reopen the app
6. Don't sign in yet!

### Option 2: Clear localStorage via Console
1. Open DevTools (F12)
2. Go to **Console** tab
3. Run this command:
```javascript
localStorage.clear(); sessionStorage.clear(); location.reload();
```

## Then: Fix the Database Policies

The 500 error is caused by circular RLS policies. Go to your **Supabase SQL Editor** and run this:

```sql
-- Drop the problematic "true" policy
DROP POLICY IF EXISTS "Users can view pool memberships" ON public.pool_members;

-- Create a better policy that avoids recursion
CREATE POLICY "Users can view pool memberships"
    ON public.pool_members
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.pool_members pm
            WHERE pm.pool_id = pool_members.pool_id
            AND pm.user_id = auth.uid()
        )
        OR
        user_id = auth.uid()
    );

-- Fix the pools policy too
DROP POLICY IF EXISTS "Users can view pools they belong to" ON public.pools;

CREATE POLICY "Users can view pools they belong to"
    ON public.pools
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.pool_members pm
            WHERE pm.pool_id = pools.id
            AND pm.user_id = auth.uid()
        )
    );
```

Or run the complete migration file: `supabase/migrations/003_fix_rls_properly.sql`

## Why This Works

The previous fix (`USING (true)`) allowed anyone to see all pool memberships, but created a different circular dependency with the `pools` table. The new fix uses `EXISTS` with proper scoping to avoid recursion while still maintaining security.

## After Applying Fix

1. Refresh the page
2. Try signing in again
3. Try creating a pool - it should work now!

