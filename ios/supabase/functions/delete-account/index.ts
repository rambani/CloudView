/**
 * delete-account
 *
 * Called by the iOS app when a user requests account deletion.
 * Steps:
 *   1. Verify the user's JWT (they must be authenticated)
 *   2. Delete all user data via RPC (respects RLS, sightings cascade to likes/reports)
 *   3. Delete the auth user using the service role key (not possible from client)
 *
 * Setup:
 *   supabase functions deploy delete-account
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return new Response("Unauthorized", { status: 401 });

  // Identify the requesting user
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return new Response("Unauthorized", { status: 401 });

  // Delete all user content (sightings → likes/reports cascade)
  const { error: dataError } = await userClient.rpc("delete_user_account");
  if (dataError) {
    console.error("Data deletion failed:", dataError.message);
    return new Response("Failed to delete user data", { status: 500 });
  }

  // Delete the auth user — requires service role
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { error: authError } = await adminClient.auth.admin.deleteUser(user.id);
  if (authError) {
    console.error("Auth deletion failed:", authError.message);
    return new Response("Failed to delete auth user", { status: 500 });
  }

  return new Response("Account deleted", { status: 200 });
});
