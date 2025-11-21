# 🎱 Online Pool Application

## Overview & Objective

The primary goal of this project is to replace an existing manual pool tracking system (currently managed via Google Sheets) with a simple, dynamic, and fully hosted web application.

The application must support basic user authentication and real-time data tracking to allow a small group of friends/family to participate in and view the pool standings.

## Technical Stack & Constraints

This project has strict constraints regarding deployment and cost, aiming for the free tiers of all services.

| Component | Technology | Tier/Constraint | Notes |
|-----------|------------|-----------------|-------|
| Hosting | Cloudflare Pages | Free Tier | Static site deployment. |
| Backend/DB | Supabase | Free Tier | Used for Authentication (Auth) and Database (Postgres). |
| Frontend | HTML, Tailwind CSS, Vanilla JavaScript | Single-File Mandate | The entire application (HTML, CSS, JS) must be contained within a single index.html file for simplicity and rapid deployment. |

### Environment Variables

The following keys must be injected into the application's environment configuration:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

**Crucial Security Note:** Row Level Security (RLS) must be enabled and correctly configured on all Supabase database tables to ensure data safety, as the Anon key will be public in the client-side code.

## Key Features (Minimum Viable Product)

The initial iteration should focus on the following core functionality:

- **User Authentication:** Implement a simple sign-in/sign-up flow using Supabase Auth (e.g., Email/Password or Magic Link). All data interaction must be linked to an authenticated user (auth.uid()).

- **Pool Data Model:** Create the initial database structure in Supabase to track:
  - **Players:** Linked to Supabase Auth users.
  - **Picks:** Where users submit their initial choices (e.g., user_id, pick_data).
  - **Scores/Standings:** Automatically calculated or manually updated via an admin interface (future feature, for now, just display the raw data).


- **Real-time Display:** Use Supabase Realtime to update the application interface automatically when scores or standings change.

- **Standings View:** A basic, visually clear list of players and their current progress.

## User Data Model

The database structure for users is designed to extend Supabase Auth with additional profile information.

### Users Table

The `users` table stores user profile data and is linked to Supabase Auth via the `id` field.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, REFERENCES auth.users(id) | Links to Supabase Auth user ID (auth.uid()) |
| `email` | TEXT | UNIQUE, NOT NULL | User's email address (synced from auth.users) |
| `display_name` | TEXT | | Optional display name for the user |
| `created_at` | TIMESTAMP | DEFAULT now() | Timestamp when the user profile was created |
| `updated_at` | TIMESTAMP | DEFAULT now() | Timestamp when the user profile was last updated |

### Security Considerations

- **Row Level Security (RLS):** Must be enabled on the `users` table
- **User Access:** Users can read their own profile and update their own `display_name`
- **Public Read:** Other users' profiles may be readable for displaying standings (depending on requirements)
- **Auth Integration:** The `id` field must match `auth.uid()` to ensure data integrity

### Database Triggers

Consider implementing triggers to:
- Automatically create a user profile when a new user signs up via Supabase Auth
- Update the `updated_at` timestamp on profile updates

## Pool Data Model

The pool tracking system uses a many-to-many relationship between users and pools, with role-based access control to distinguish between pool managers and members.

### Pools Table

The `pools` table stores pool information and status.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Unique identifier for the pool |
| `name` | TEXT | NOT NULL | Name of the pool |
| `description` | TEXT | | Optional description of the pool |
| `status` | TEXT | NOT NULL, DEFAULT 'active', CHECK (status IN ('active', 'archived')) | Pool status: 'active' or 'archived' |
| `created_at` | TIMESTAMP | DEFAULT now() | Timestamp when the pool was created |
| `updated_at` | TIMESTAMP | DEFAULT now() | Timestamp when the pool was last updated |

### Pool Members Table

The `pool_members` table is a junction table that tracks the relationship between users and pools, including their role.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Unique identifier for the membership record |
| `pool_id` | UUID | NOT NULL, REFERENCES pools(id) ON DELETE CASCADE | Foreign key to the pool |
| `user_id` | UUID | NOT NULL, REFERENCES users(id) ON DELETE CASCADE | Foreign key to the user |
| `role` | TEXT | NOT NULL, DEFAULT 'member', CHECK (role IN ('manager', 'member')) | User's role in the pool: 'manager' or 'member' |
| `joined_at` | TIMESTAMP | DEFAULT now() | Timestamp when the user joined the pool |
| UNIQUE (`pool_id`, `user_id`) | | | Ensures a user can only have one role per pool |

### Querying User Pools

To retrieve pools for a given user, use the following query patterns:

**Joined Pools (all pools where user is a member or manager):**
```sql
SELECT p.*, pm.role, pm.joined_at
FROM pools p
INNER JOIN pool_members pm ON p.id = pm.pool_id
WHERE pm.user_id = auth.uid()
  AND p.status = 'active'
ORDER BY pm.joined_at DESC;
```

**Managed Pools (pools where user is a manager):**
```sql
SELECT p.*, pm.joined_at
FROM pools p
INNER JOIN pool_members pm ON p.id = pm.pool_id
WHERE pm.user_id = auth.uid()
  AND pm.role = 'manager'
  AND p.status = 'active'
ORDER BY p.created_at DESC;
```

**Archived Pools:**
```sql
SELECT p.*, pm.role, pm.joined_at
FROM pools p
INNER JOIN pool_members pm ON p.id = pm.pool_id
WHERE pm.user_id = auth.uid()
  AND p.status = 'archived'
ORDER BY p.updated_at DESC;
```

### Security Considerations

- **Row Level Security (RLS):** Must be enabled on both `pools` and `pool_members` tables
- **Pool Access:** Users can only view pools they are members of
- **Pool Management:** Only users with `role = 'manager'` can update pool details or change pool status
- **Membership Management:** Managers can add/remove members; users can leave pools they are members of (but not managers)

### Database Triggers

Consider implementing triggers to:
- Update the `updated_at` timestamp on the `pools` table when pool data changes
- Automatically set the pool creator as a manager when a new pool is created
- Prevent the last manager from being removed from a pool (or automatically archive the pool)

## Contestants, Parameters, and Scoring Data Model

The system tracks contestants, custom voting parameters, member votes, and scoring for each pool.

### Contestants Table

The `contestants` table tracks all contestants in a pool and their elimination status.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Unique identifier for the contestant |
| `pool_id` | UUID | NOT NULL, REFERENCES pools(id) ON DELETE CASCADE | Foreign key to the pool |
| `name` | TEXT | NOT NULL | Name of the contestant |
| `eliminated_at` | TIMESTAMP | | Date/time when the contestant was eliminated (NULL if still active) |
| `created_at` | TIMESTAMP | DEFAULT now() | Timestamp when the contestant was added |

### Parameters Table

The `parameters` table stores custom voting questions/parameters that managers create for each pool. Each parameter has an associated point value.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Unique identifier for the parameter |
| `pool_id` | UUID | NOT NULL, REFERENCES pools(id) ON DELETE CASCADE | Foreign key to the pool |
| `name` | TEXT | NOT NULL | The question/parameter text (e.g., "Who will be eliminated next?") |
| `point_value` | INTEGER | NOT NULL, DEFAULT 1, CHECK (point_value > 0) | Points awarded for a correct answer |
| `episode_number` | INTEGER | | Optional episode number for organization |
| `status` | TEXT | NOT NULL, DEFAULT 'open', CHECK (status IN ('open', 'closed', 'scored')) | Parameter status: 'open' (accepting votes), 'closed' (voting closed, awaiting results), 'scored' (results entered, points awarded) |
| `deadline` | TIMESTAMP | | Optional deadline for submitting votes |
| `created_at` | TIMESTAMP | DEFAULT now() | Timestamp when the parameter was created |
| `updated_at` | TIMESTAMP | DEFAULT now() | Timestamp when the parameter was last updated |

### Votes Table

The `votes` table stores member submissions for each parameter. Each member can submit one vote per parameter.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Unique identifier for the vote |
| `parameter_id` | UUID | NOT NULL, REFERENCES parameters(id) ON DELETE CASCADE | Foreign key to the parameter |
| `user_id` | UUID | NOT NULL, REFERENCES users(id) ON DELETE CASCADE | Foreign key to the user who submitted the vote |
| `contestant_id` | UUID | NOT NULL, REFERENCES contestants(id) ON DELETE RESTRICT | The contestant the user selected as their answer |
| `submitted_at` | TIMESTAMP | DEFAULT now() | Timestamp when the vote was submitted |
| UNIQUE (`parameter_id`, `user_id`) | | | Ensures a user can only vote once per parameter |

### Correct Answers Table

The `correct_answers` table stores the correct answers entered by pool managers after episodes air.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4() | Unique identifier for the correct answer record |
| `parameter_id` | UUID | NOT NULL, UNIQUE, REFERENCES parameters(id) ON DELETE CASCADE | Foreign key to the parameter (one correct answer per parameter) |
| `contestant_id` | UUID | NOT NULL, REFERENCES contestants(id) ON DELETE RESTRICT | The correct contestant answer |
| `entered_by` | UUID | NOT NULL, REFERENCES users(id) | The manager who entered the correct answer |
| `entered_at` | TIMESTAMP | DEFAULT now() | Timestamp when the correct answer was entered |

### Scoring Calculation

Scores are calculated dynamically by comparing votes with correct answers. The following query calculates total points for each user in a pool:

```sql
-- Calculate total points for all users in a pool
SELECT 
    v.user_id,
    u.display_name,
    COALESCE(SUM(p.point_value), 0) as total_points
FROM pool_members pm
INNER JOIN users u ON pm.user_id = u.id
LEFT JOIN votes v ON v.user_id = pm.user_id
LEFT JOIN parameters p ON v.parameter_id = p.id
LEFT JOIN correct_answers ca ON ca.parameter_id = p.id
WHERE pm.pool_id = :pool_id
  AND p.status = 'scored'
  AND v.contestant_id = ca.contestant_id
GROUP BY v.user_id, u.display_name
ORDER BY total_points DESC;
```

**Alternative: Materialized Scores Table**

For better performance with large datasets, consider a `pool_scores` table that is updated via triggers when correct answers are entered:

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `pool_id` | UUID | NOT NULL, REFERENCES pools(id) ON DELETE CASCADE | Foreign key to the pool |
| `user_id` | UUID | NOT NULL, REFERENCES users(id) ON DELETE CASCADE | Foreign key to the user |
| `total_points` | INTEGER | NOT NULL, DEFAULT 0 | Total points accumulated by the user |
| `updated_at` | TIMESTAMP | DEFAULT now() | Timestamp when the score was last updated |
| PRIMARY KEY (`pool_id`, `user_id`) | | | Composite primary key |

### Query Examples

**Get all active contestants for a pool:**
```sql
SELECT * FROM contestants
WHERE pool_id = :pool_id
  AND eliminated_at IS NULL
ORDER BY name;
```

**Get all open parameters for voting:**
```sql
SELECT * FROM parameters
WHERE pool_id = :pool_id
  AND status = 'open'
  AND (deadline IS NULL OR deadline > now())
ORDER BY episode_number, created_at;
```

**Get a user's votes for a pool:**
```sql
SELECT v.*, p.name as parameter_name, c.name as contestant_name
FROM votes v
INNER JOIN parameters p ON v.parameter_id = p.id
INNER JOIN contestants c ON v.contestant_id = c.id
WHERE v.user_id = auth.uid()
  AND p.pool_id = :pool_id
ORDER BY p.created_at DESC;
```

**Get parameters awaiting correct answers (for managers):**
```sql
SELECT p.*, COUNT(v.id) as vote_count
FROM parameters p
LEFT JOIN votes v ON p.id = v.parameter_id
WHERE p.pool_id = :pool_id
  AND p.status = 'closed'
GROUP BY p.id
ORDER BY p.episode_number, p.created_at;
```

### Security Considerations

- **Row Level Security (RLS):** Must be enabled on all tables
- **Contestant Management:** Only managers can add/edit/eliminate contestants
- **Parameter Management:** Only managers can create/edit parameters and enter correct answers
- **Vote Submission:** Members can only submit votes for parameters in 'open' status and only one vote per parameter
- **Vote Modification:** Members can update their votes only before the parameter deadline (if set) or before status changes to 'closed'
- **Correct Answer Entry:** Only managers can enter correct answers, and once entered, the parameter status should automatically change to 'scored'

### Database Triggers

Consider implementing triggers to:
- Automatically update `parameters.updated_at` when parameter data changes
- Automatically set `parameters.status` to 'scored' when a correct answer is entered
- Update `pool_scores` table (if used) when correct answers are entered and votes match
- Prevent vote submission after parameter deadline or when status is not 'open'
- Prevent entering correct answers for parameters that don't have any votes

## Next Steps for Development

The initial file generated should be a functional skeleton, including:

- Basic UI layout using Tailwind CSS (must be fully responsive).
- Firebase/Supabase client initialization using the environment variables.
- A placeholder login/logout button and a display area for the current user's ID/email.
- A guard condition to only show application content to authenticated users.

The immediate next step is to flesh out the data models and the pick submission form.
