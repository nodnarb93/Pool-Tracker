# Supabase Database Setup

This directory contains SQL migration files for setting up the Pool Tracker database schema.

## Quick Start

1. **Open Supabase Dashboard**
   - Go to your Supabase project dashboard
   - Navigate to the SQL Editor

2. **Run the Migration**
   - Open the file `migrations/001_initial_schema.sql`
   - Copy the entire contents
   - Paste into the Supabase SQL Editor
   - Click "Run" to execute

3. **Verify Setup**
   - Check the "Table Editor" to see all created tables:
     - `users`
     - `pools`
     - `pool_members`
     - `contestants`
     - `parameters`
     - `votes`
     - `correct_answers`
     - `pool_scores`
   - Verify RLS is enabled on all tables (should show a shield icon)

## What Gets Created

### Tables
- **users**: User profiles linked to Supabase Auth
- **pools**: Pool information and status
- **pool_members**: Many-to-many relationship between users and pools with roles
- **contestants**: Contestants in each pool
- **parameters**: Voting questions/parameters for each pool
- **votes**: User votes for parameters
- **correct_answers**: Correct answers entered by managers
- **pool_scores**: Materialized scores for performance

### Security (RLS Policies)
- Row Level Security enabled on all tables
- Users can only access data for pools they belong to
- Managers have elevated permissions for pool management
- Vote submission restricted to open parameters

### Triggers
- Auto-create user profile on signup
- Auto-update timestamps (`updated_at`)
- Auto-set parameter status to 'scored' when correct answer entered
- Auto-update `pool_scores` when correct answers are entered
- Initialize scores for new pool members

### Indexes
- Performance indexes on frequently queried columns

## Troubleshooting

### Error: "relation already exists"
If you see this error, some tables may already exist. You can either:
1. Drop existing tables and re-run (⚠️ **WARNING**: This will delete all data)
2. Manually create only the missing tables

### Error: "permission denied"
Make sure you're running the SQL as a database administrator or with sufficient privileges.

### RLS Policies Not Working
- Verify RLS is enabled: Check the table properties in Supabase dashboard
- Check that policies are created: Go to Authentication > Policies in Supabase dashboard
- Ensure you're authenticated when testing queries

## Next Steps

After running the migration:

1. **Configure Environment Variables** in your deployment:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_ANON_KEY`: Your Supabase anonymous key (found in Settings > API)

2. **Test the Application**:
   - Sign up a new user
   - Create a pool
   - Add contestants
   - Create parameters
   - Submit votes

3. **Optional: Seed Test Data**
   - You can create a seed script to populate initial test data if needed

## Manual Pool Creation

If you need to manually create a pool and add yourself as manager, you can run:

```sql
-- Replace 'your-user-id' with your actual auth.uid()
-- Replace 'Pool Name' and 'Description' with your values

INSERT INTO public.pools (name, description, status)
VALUES ('Pool Name', 'Description', 'active')
RETURNING id;

-- Then add yourself as manager (replace pool_id and user_id)
INSERT INTO public.pool_members (pool_id, user_id, role)
VALUES ('pool-id-here', 'your-user-id', 'manager');
```

## Support

If you encounter issues, check:
- Supabase documentation: https://supabase.com/docs
- RLS documentation: https://supabase.com/docs/guides/auth/row-level-security

